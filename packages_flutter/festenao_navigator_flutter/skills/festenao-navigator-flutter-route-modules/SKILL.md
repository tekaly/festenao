---
name: festenao-navigator-flutter-route-modules
description: >-
  Use when assembling a Festenao Flutter app's go_router tree from feature
  packages, or white-labeling one screen of it: FeatureRouteModule (moduleId,
  routes), NestedFeatureRouteModule (parentRouteName), FeatureRouteModuleBase,
  FeatureRouteModuleListExt.findModuleOrNull,
  ModularRouteResolver.assembleRoutes(baseModules:, customOverrides:) and
  routeMatchesOverride, from
  package:festenao_navigator_flutter/festenao_navigator_flutter.dart.
---

# Modular route assembly (festenao_navigator_flutter)

Each feature package exposes a `FeatureRouteModule` with its own routes and
path definitions, knowing nothing about the host app; the app calls
`ModularRouteResolver.assembleRoutes` to merge those modules and replace the
screens it wants to change, then hands the result to `GoRouter`.

## Guidelines

* Dependency (not on pub.dev, git only):

  ```yaml
  dependencies:
    festenao_navigator_flutter:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_navigator_flutter
  ```

* Single import:
  `package:festenao_navigator_flutter/festenao_navigator_flutter.dart` — it
  re-exports go_router, so `RouteBase`, `GoRoute`, `GoRouter` come from the
  facade. Never import `package:festenao_navigator_flutter/src/...`.
* A feature package implements `FeatureRouteModule`: `String get moduleId` (a
  stable id, unique in the app: `'school'`, `'auth'`) and
  `List<RouteBase> get routes`. For a module with no state of its own, use
  `FeatureRouteModuleBase(moduleId: ..., routes: [...])` instead of writing a
  class. Build the routes from `RoutePathDef.goRoute` and export the
  definitions publicly — that is how the app and other features navigate in.
* A feature package must not import another feature package nor hardcode a
  location from one. To contribute a screen **inside** another module's
  branch, implement `NestedFeatureRouteModule`: same contract plus
  `String get parentRouteName`, the `GoRoute.name` of the route to hang from.
  The resolver mounts it, so neither module imports the other.
* Prefer nesting over a top level route for anything conceptually below
  another screen: a top level route has no parent page, so a fresh page load on
  the web lands on a screen with nothing to pop (go_router never synthesises a
  stack from the url). If you must mount at the top level, give the screen a
  `RouteUpBackButton(upPath: ...)`.
* `ModularRouteResolver.assembleRoutes({required List<FeatureRouteModule>
  baseModules, List<RouteBase> customOverrides = const []})` is static and
  synchronous; call it once at app init. Order of operations:
  1. plain modules contribute their routes at the top level, in module order;
  2. nested modules are mounted under `parentRouteName`, searched anywhere in
     the assembled tree — so the order of `baseModules` does not matter for
     nesting;
  3. `customOverrides` are applied, in order.
* It throws an `ArgumentError` for two modules sharing a `moduleId`, and for a
  nested module naming a parent route no module declares. Both are wiring
  mistakes, not silently dropped.
* Override matching (`routeMatchesOverride(route, override)`, exported so you
  can unit-test it) is deliberately deterministic: when **both** routes are
  named, the names must be equal (a name never matches a different name, even
  on the same path); otherwise the `GoRoute.path` must be exactly equal. Only
  `GoRoute`s match — a `ShellRoute` has no identity, override the routes it
  wraps. So: name every route.
* An override replaces the matched route **in place**, anywhere in the tree,
  keeping the surrounding order and nesting; it brings its own `routes:`
  subtree, so re-declare the children you want to keep. An override matching
  nothing is appended at the top level — that is how the app adds its own
  routes (an accidental non-match therefore shows up as a duplicated screen,
  not an error: check the name).
* `findModuleOrNull(moduleId)` (`FeatureRouteModuleListExt` on
  `List<FeatureRouteModule>`) looks a module up in the app's list, e.g. to
  decide whether a feature is enabled for a flavor.
* Anti-patterns: assembling routes inside a widget `build` or a provider that
  rebuilds; passing the same module instance twice; overriding by path when the
  base route is named (it will not match and will be appended).
* Testing: assembly is pure Dart, no widget pumping. Build modules with
  `FeatureRouteModuleBase` and `GoRoute`s whose `builder` throws, assemble, and
  assert on the resulting names/paths tree.

## Examples

### A feature package's module

```dart
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';

/// Public definitions of the school feature.
final schoolListPath = RoutePathDef.parse('/school', name: 'school_list');

/// `/school/:school_id`
final schoolPath = schoolListPath.child(':school_id', name: 'school');

/// The routes of the school feature.
class SchoolRouteModule implements FeatureRouteModule {
  @override
  String get moduleId => 'school';

  @override
  List<RouteBase> get routes => [
    schoolListPath.goRoute(
      builder: (context, state) => const Scaffold(body: Text('schools')),
      routes: [
        schoolPath.goRoute(
          builder: (context, state) =>
              Scaffold(body: Text(state.pathParameter('school_id'))),
        ),
      ],
    ),
  ];
}

/// A module with nothing but routes needs no class.
FeatureRouteModule authRouteModule() => FeatureRouteModuleBase(
  moduleId: 'auth',
  routes: [
    RoutePathDef.parse('/login', name: 'login').goRoute(
      builder: (context, state) => const Scaffold(body: Text('login')),
    ),
  ],
);
```

### A module contributing inside another module's branch

```dart
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';

final projectPath = RoutePathDef.parse('/project/:project_id', name: 'project');

/// `/project/:project_id/blog_demo`, mounted under the 'project' route.
final blogPath = projectPath.child('blog_demo', name: 'blog_demo');

/// The blog feature hangs from the project route, without importing the
/// module that declares it: it only names it.
class BlogRouteModule implements NestedFeatureRouteModule {
  @override
  String get moduleId => 'blog';

  @override
  String get parentRouteName => 'project';

  @override
  List<RouteBase> get routes => [
    blogPath.goRoute(
      builder: (context, state) => const Scaffold(body: Text('blog')),
    ),
  ];
}
```

### The app assembles, overrides, and builds the router

```dart
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';

/// Router of a white-labeled app: the modules' routes, with the school list
/// screen replaced by our own.
GoRouter buildRouter(List<FeatureRouteModule> modules) {
  var routes = ModularRouteResolver.assembleRoutes(
    baseModules: modules,
    customOverrides: [
      // Matches the module route *named* 'school_list' and replaces it in
      // place; its children must be re-declared here if we keep them.
      RoutePathDef.parse('/school', name: 'school_list').goRoute(
        builder: (context, state) => const Scaffold(body: Text('my schools')),
      ),
      // Matches nothing: appended at the top level, i.e. an app-only route.
      RoutePathDef.parse('/about', name: 'about').goRoute(
        builder: (context, state) => const Scaffold(body: Text('about')),
      ),
    ],
  );
  return GoRouter(routes: routes, initialLocation: '/school');
}

/// Is a feature part of this flavor?
bool hasBlog(List<FeatureRouteModule> modules) =>
    modules.findModuleOrNull('blog') != null;
```

### Unit testing the assembled tree

```dart
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _never(BuildContext context, GoRouterState state) =>
    throw StateError('never built');

void main() {
  test('an override replaces the named route in place', () {
    var base = FeatureRouteModuleBase(
      moduleId: 'school',
      routes: [
        GoRoute(path: '/school', name: 'school_list', builder: _never),
        GoRoute(path: '/login', name: 'login', builder: _never),
      ],
    );
    var routes = ModularRouteResolver.assembleRoutes(
      baseModules: [base],
      customOverrides: [
        GoRoute(path: '/school', name: 'school_list', builder: _never),
      ],
    );
    expect(routes.length, 2);
    expect((routes.first as GoRoute).name, 'school_list');
    expect(
      routeMatchesOverride(routes.first, routes.first),
      isTrue,
    );
  });
}
```

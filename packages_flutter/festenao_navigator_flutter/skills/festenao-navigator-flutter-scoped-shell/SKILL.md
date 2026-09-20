---
name: festenao-navigator-flutter-scoped-shell
description: >-
  Use when a branch of a Festenao go_router tree needs riverpod state scoped to
  the active route (a current entity id from a path parameter, a shared layout,
  disposal on leaving the branch): providerScopeShellRoute(overrides:, routes:,
  builder:, scopeKey:), the ScopedShellOverrides / ScopedShellBuilder /
  ScopedShellKeyBuilder typedefs, scopedFrom(context, child:), ProviderScope
  overrideWithValue and the absolute:true rule for a top level ShellRoute's
  children, from
  package:festenao_navigator_flutter/festenao_navigator_flutter.dart.
---

# Route-scoped riverpod state (festenao_navigator_flutter)

`providerScopeShellRoute` is a `ShellRoute` that wraps its children in a
`ProviderScope` whose overrides are computed from the active `GoRouterState`.
A whole branch (`/school/:school_id/...`) then reads the current school id — and
anything derived from it — as plain providers, and leaving the branch disposes
them.

## Guidelines

* Dependency (not on pub.dev, git only):

  ```yaml
  dependencies:
    festenao_navigator_flutter:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_navigator_flutter
  ```

* Imports: `package:festenao_navigator_flutter/festenao_navigator_flutter.dart`
  (it re-exports go_router: `ShellRoute`, `RouteBase`, `GoRouter`,
  `GoRouterState`) plus `package:flutter_riverpod/flutter_riverpod.dart` for
  `Provider`, `ConsumerWidget`, `ProviderScope`. Never import
  `package:festenao_navigator_flutter/src/...`.
* `providerScopeShellRoute({required ScopedShellOverrides overrides, required
  List<RouteBase> routes, ScopedShellBuilder? builder, ScopedShellKeyBuilder?
  scopeKey, GlobalKey<NavigatorState>? navigatorKey, GlobalKey<NavigatorState>?
  parentNavigatorKey, List<NavigatorObserver>? observers, String?
  restorationScopeId})` returns a plain `ShellRoute`; put it in a `routes:` list
  like any other route.
  * `overrides: (GoRouterState state) => [ ... ]` — usually
    `someProvider.overrideWithValue(state.pathParameter('school_id'))`.
  * `builder: (context, state, child) => Layout(child: child)` is optional and
    is built **inside** the scope, so it can read the overridden providers.
  * `scopeKey: (state) => state.pathParameters['school_id']` is optional and
    decides what happens when the parameter changes.
* The scoped provider must be declared so it *can* be overridden, and anything
  **derived** from it must list it in its own `dependencies` — otherwise the
  derived provider is created in the root container, where the override does
  not exist, and it throws:

  ```
  final currentSchoolIdProvider = Provider<String>(
    (ref) => throw StateError('not scoped'),
  );
  final schoolNameProvider = Provider<String>(
    (ref) => ref.watch(currentSchoolIdProvider),
    dependencies: [currentSchoolIdProvider],
  );
  ```

  With riverpod_generator this is `@Riverpod(dependencies: [currentSchoolId])`.
  Only the providers listed in `overrides` are scoped.
* `scopeKey` decides update vs recreate when going from `/school/124/...` to
  `/school/125/...`: **without** it the same `ProviderScope` is kept and only
  the overridden values change (cheap, but state cached in a scoped provider
  survives the school change); **with** it (returning the id) the scope is torn
  down and rebuilt, disposing everything scoped to the previous school. Choose
  deliberately; when in doubt, pass the id.
* go_router rule that bites here: the **direct children** of a top level
  `ShellRoute` must be declared `absolute: true` in `goRoute()` (or use an
  absolute `GoRoute.path`), because a shell adds nothing to the location.
  Deeper routes nest normally and stay relative.
* A route pushed on the **root** navigator (a full screen modal with
  `parentNavigatorKey: rootNavigatorKey`), and anything shown via
  `showDialog` / `showModalBottomSheet` with a root context, is built outside
  the shell subtree and loses the scope. Wrap it:
  `scopedFrom(context, child: const StudentEditDialog())`. It re-exposes the
  existing container through `UncontrolledProviderScope` — it does not own it,
  so do not use it to create a scope, and do not use it after the shell is
  gone.
* Anti-patterns: wrapping each screen of a branch in its own `ProviderScope`;
  reading the scoped provider from a route outside the shell; a derived
  provider without `dependencies`; nesting the shell's children relatively when
  the shell is at the top level (the location silently loses a segment).
* Testing: pump `MaterialApp.router(routerConfig: router)` and navigate with
  `context.goPath(...)`. To tell a scope *update* from a scope *recreation*,
  collect `ProviderScope.containerOf(context, listen: false)` in the shell
  `builder` and compare identities across navigations — that is what
  `test/scoped_shell_route_test.dart` does.

## Examples

### A branch scoped by a path parameter

```dart
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden by the shell; reading it outside the branch is a bug.
final currentSchoolIdProvider = Provider<String>(
  (ref) => throw StateError('not scoped'),
);

/// Derived from a scoped provider: it MUST declare it in dependencies.
final schoolTitleProvider = Provider<String>(
  (ref) => 'School ${ref.watch(currentSchoolIdProvider)}',
  dependencies: [currentSchoolIdProvider],
);

final schoolListPath = RoutePathDef.parse('/school', name: 'school_list');
final schoolPath = schoolListPath.child(':school_id', name: 'school');
final studentListPath = schoolPath.child('student', name: 'student_list');

GoRouter buildRouter() => GoRouter(
  initialLocation: '/school',
  routes: [
    schoolListPath.goRoute(
      builder: (context, state) => const Scaffold(body: Text('schools')),
    ),
    providerScopeShellRoute(
      overrides: (state) => [
        currentSchoolIdProvider.overrideWithValue(
          state.pathParameter('school_id'),
        ),
      ],
      // Changing school disposes everything scoped to the previous one.
      scopeKey: (state) => state.pathParameters['school_id'],
      // Built inside the scope: it can read the overridden providers.
      builder: (context, state, child) => Scaffold(
        appBar: AppBar(title: const SchoolTitle()),
        body: child,
      ),
      routes: [
        schoolPath.goRoute(
          // Direct child of a top level shell: no parent route to be
          // relative to.
          absolute: true,
          builder: (context, state) => const SchoolHome(),
          routes: [
            // Deeper routes nest normally.
            studentListPath.goRoute(
              builder: (context, state) => const Text('students'),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Reads the scoped state like any provider.
class SchoolTitle extends ConsumerWidget {
  /// Constructor.
  const SchoolTitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text(ref.watch(schoolTitleProvider));
}

/// Home of the scoped branch.
class SchoolHome extends ConsumerWidget {
  /// Constructor.
  const SchoolHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text('id ${ref.watch(currentSchoolIdProvider)}');
}
```

### Keeping the scope in a dialog or a root-navigator route

```dart
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentSchoolIdProvider = Provider<String>(
  (ref) => throw StateError('not scoped'),
);

/// A dialog is built from the root navigator, outside the shell subtree:
/// re-expose the scope or the scoped providers throw.
Future<void> editStudent(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => scopedFrom(context, child: const StudentEditDialog()),
);

/// Content of the dialog, reading the scoped provider.
class StudentEditDialog extends ConsumerWidget {
  /// Constructor.
  const StudentEditDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AlertDialog(
    title: Text('School ${ref.watch(currentSchoolIdProvider)}'),
  );
}

/// Same thing for a full screen route pushed on the root navigator.
RouteBase fullScreenEditRoute(GlobalKey<NavigatorState> rootNavigatorKey) =>
    RoutePathDef.parse('/school/:school_id/edit', name: 'school_edit').goRoute(
      absolute: true,
      builder: (context, state) =>
          scopedFrom(context, child: const StudentEditDialog()),
    );
```

### Several scoped values, and a shell with no layout

```dart
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentProjectIdProvider = Provider<String>(
  (ref) => throw StateError('not scoped'),
);
final currentSectionProvider = Provider<String?>((ref) => null);

final projectPath = RoutePathDef.parse('/project/:project_id', name: 'project');

/// No builder: the shell only provides the scope, the children draw
/// themselves. The overrides callback is free to read anything of the state.
RouteBase projectScope(List<RouteBase> routes) => providerScopeShellRoute(
  overrides: (state) => [
    currentProjectIdProvider.overrideWithValue(
      state.pathParameter('project_id'),
    ),
    currentSectionProvider.overrideWithValue(state.uri.queryParameters['tab']),
  ],
  scopeKey: (state) => state.pathParameterOrNull('project_id'),
  routes: routes,
);

/// The branch itself.
List<RouteBase> projectRoutes() => [
  projectScope([
    projectPath.goRoute(
      absolute: true,
      builder: (context, state) => const Scaffold(body: Text('project')),
    ),
  ]),
];
```

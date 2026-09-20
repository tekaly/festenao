---
name: festenao-navigator-flutter-route-paths
description: >-
  Use when declaring go_router paths or navigating in a Festenao Flutter app
  without string concatenation: RoutePathDef (parse, child, path, relativePath,
  relativeTo, location, locationFrom, parameterNames), RoutePathPart, the
  goRoute({builder, pageBuilder, routes, absolute, ancestor}) extension,
  GoRouterState.pathParameter/pathParameterOrNull, the BuildContext extension
  goPath/pushPath/replacePath/goDeeper/pushDeeper/goSibling/goUp/popOrGoPath/
  popOrGoUp, RouteUpBackButton, and routeLocationAppend/Parent/Sibling/Segments
  from package:festenao_navigator_flutter/festenao_navigator_flutter.dart.
---

# Typed route paths and relative navigation (festenao_navigator_flutter)

`festenao_navigator_flutter` declares each screen's location once as a
`RoutePathDef` chained from its parent, so nested `GoRoute` paths, concrete
locations and path parameter inheritance all come from the same object instead
of hand-built strings.

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
  `package:festenao_navigator_flutter/festenao_navigator_flutter.dart`. It
  re-exports `package:go_router/go_router.dart`, so do **not** import go_router
  separately (`GoRouter`, `GoRoute`, `RouteBase`, `GoRouterState`, `ShellRoute`
  all come from the facade). Never import
  `package:festenao_navigator_flutter/src/...`.
* Declare the paths of a feature once, at the top level of a library, and make
  them public — that is how another package navigates to them:

  ```
  var schoolListPath = RoutePathDef.parse('/school', name: 'school_list');
  var schoolPath = schoolListPath.child(':school_id', name: 'school');
  ```

  `RoutePathDef.parse(path, {parent, name})` splits on `/` (leading and
  trailing separators are ignored), `:x` segments becoming `RoutePathPart`
  parameters. `child(path, {name})` builds a definition whose `parent` is the
  receiver. **Always pass `name`**: it becomes `GoRoute.name` and it is the
  identity route overrides match on.
* Reading a definition: `path` is the absolute definition
  (`/school/:school_id/student/:student_id`), `relativePath` is the part
  relative to `parent` (what a nested `GoRoute` wants), `relativeTo(ancestor)`
  is the part relative to any ancestor (throws `ArgumentError` if it is not
  one), `parameterNames` lists the parameters in path order.
* Building the route: `def.goRoute(builder: ..., routes: [...])` uses
  `relativePath` and `name` automatically. Two flags matter:
  * `absolute: true` when the `GoRoute` is **not** nested under a `GoRoute` for
    `def.parent` — typically a direct child of a top level `ShellRoute` (a
    shell contributes nothing to the location), or a route mounted at the top
    level on purpose.
  * `ancestor: someDef` when the go_router tree nests less deeply than the
    definition tree (a definition level with no route of its own).
* Concrete locations: `def.location({'school_id': '124'})` — it **throws an
  `ArgumentError` naming the first missing parameter** instead of navigating
  nowhere, and URL-encodes the values. `def.locationFrom(state, parameters:
  {...})` starts from `state.pathParameters` and completes/overrides them; that
  is the parameter inheritance.
* Inside a screen, use the `BuildContext` extension rather than `GoRouter.of`:
  * `context.goPath(def, parameters: {...}, extra: ...)`, `pushPath<T>(...)`
    (returns a `Future<T?>`), `replacePath<T>(...)` — all inherit the active
    path parameters.
  * `goDeeper('clas/789')` / `pushDeeper<T>(...)` append to the active
    location; `goSibling('clas', count: 2)` replaces the last `count`
    segments; `goUp([count])` drops them.
  * `routeUri`, `routeLocation`, `routePathParameters` read the active route.
* `goUp` is **not** `pop`: it rewrites the location, so it also works on a
  screen opened directly by a deep link, where there is nothing to pop. For the
  general case use `context.popOrGoPath(parentDef)` (pops when it can, else
  navigates to the typed parent, inheriting parameters) or `popOrGoUp(count)`.
* Give such a screen `leading: RouteUpBackButton(upPath: parentDef)` (or
  `RouteUpBackButton(upCount: 2)` when there is no definition): a `Scaffold`
  hides its automatic back button when the navigator cannot pop, leaving a
  deep-linked screen with no way out.
* In a screen builder, read parameters with the `GoRouterState` extension:
  `state.pathParameter('school_id')` throws a `StateError` when the definition
  and the screen disagree; `state.pathParameterOrNull('...')` returns null.
* Query-string free, widget free helpers are available for plain strings:
  `routeLocationSegments`, `routeLocationAppend(location, path)`,
  `routeLocationParent(location, [count])`,
  `routeLocationSibling(location, path, count:)`. `append` keeps the query
  string, `parent`/`sibling` drop it (it belonged to the location being left).
* Anti-patterns: building locations with `'$base/$id'`, calling `context.go`
  with a literal path, hardcoding another feature's location (import its
  `RoutePathDef` instead), and relying on `pop()` for a screen a deep link can
  open.
* Testing: definitions and location helpers are pure Dart — unit-test them with
  `package:test`/`flutter_test` without pumping anything. For navigation, pump
  `MaterialApp.router(routerConfig: router)` and `pumpAndSettle`.

## Examples

### Declaring a feature's paths and its route tree

```dart
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';

/// Public definitions: another package navigates through these.
final schoolListPath = RoutePathDef.parse('/school', name: 'school_list');

/// `/school/:school_id`
final schoolPath = schoolListPath.child(':school_id', name: 'school');

/// `/school/:school_id/student`
final studentListPath = schoolPath.child('student', name: 'student_list');

/// `/school/:school_id/student/:student_id`
final studentPath = studentListPath.child(':student_id', name: 'student');

/// The routes of the school feature, nested the way the definitions are.
List<RouteBase> schoolRoutes() => [
  schoolListPath.goRoute(
    builder: (context, state) => const Scaffold(body: Text('schools')),
    routes: [
      schoolPath.goRoute(
        // path is ':school_id', taken from relativePath.
        builder: (context, state) =>
            Scaffold(body: Text('school ${state.pathParameter('school_id')}')),
        routes: [
          studentListPath.goRoute(
            builder: (context, state) => const Scaffold(body: Text('students')),
            routes: [
              studentPath.goRoute(
                builder: (context, state) => Scaffold(
                  body: Text('student ${state.pathParameter('student_id')}'),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];

/// `/school/124/student/456`
String aStudentLocation() =>
    studentPath.location({'school_id': '124', 'student_id': '456'});
```

### Navigating from a screen (inheriting the active parameters)

```dart
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';

final schoolListPath = RoutePathDef.parse('/school', name: 'school_list');
final schoolPath = schoolListPath.child(':school_id', name: 'school');
final clasListPath = schoolPath.child('clas', name: 'clas_list');
final clasPath = clasListPath.child(':clas_id', name: 'clas');

/// Reached at /school/124/student/456.
class StudentScreen extends StatelessWidget {
  /// Constructor.
  const StudentScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    // Always reachable, even opened directly by a deep link.
    appBar: AppBar(leading: RouteUpBackButton(upPath: schoolPath)),
    body: Column(
      children: [
        Text(context.routeLocation),
        TextButton(
          // school_id is inherited from the active location.
          onPressed: () => context.goPath(clasPath, parameters: {'clas_id': '789'}),
          child: const Text('a class of the same school'),
        ),
        TextButton(
          // /school/124/student/456 -> /school/124/clas
          onPressed: () => context.goSibling('clas', count: 2),
          child: const Text('sideways'),
        ),
        TextButton(
          onPressed: () => context.goUp(),
          child: const Text('up (works without a stack)'),
        ),
        TextButton(
          onPressed: () => context.popOrGoPath(schoolPath),
          child: const Text('back'),
        ),
      ],
    ),
  );
}
```

### A route that is not nested under its parent's route

```dart
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';

final projectPath = RoutePathDef.parse('/project/:project_id', name: 'project');

/// Declared as a child of the project, but mounted at the top level.
final blogPath = projectPath.child('blog_demo', name: 'blog_demo');

GoRouter buildRouter() => GoRouter(
  initialLocation: '/project/x/blog_demo',
  routes: [
    projectPath.goRoute(
      // No enclosing GoRoute: the path must be the absolute one.
      absolute: true,
      builder: (context, state) => const Scaffold(body: Text('project')),
    ),
    blogPath.goRoute(
      absolute: true,
      builder: (context, state) => Scaffold(
        // Opened directly there is nothing to pop: go up to the project.
        appBar: AppBar(leading: RouteUpBackButton(upPath: projectPath)),
        body: const Text('blog'),
      ),
    ),
  ],
);
```

### Pure location helpers (no widget involved)

```dart
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';

/// String level location math, used by the context extension.
List<String> locationSamples() {
  var location = '/school/124/student/456';
  return [
    routeLocationSegments(location).join(','), // school,124,student,456
    routeLocationAppend(location, 'note/1'), // .../456/note/1
    routeLocationParent(location), // /school/124/student
    routeLocationParent(location, 2), // /school/124
    routeLocationSibling(location, 'clas', count: 2), // /school/124/clas
  ];
}

/// Definition level helpers.
List<String> definitionSamples() {
  var schoolPath = RoutePathDef.parse('/school/:school_id', name: 'school');
  var studentPath = schoolPath.child('student/:student_id', name: 'student');
  return [
    studentPath.path, // /school/:school_id/student/:student_id
    studentPath.relativePath, // student/:student_id
    studentPath.relativeTo(null), // the absolute path
    studentPath.parameterNames.join(','), // school_id,student_id
  ];
}
```

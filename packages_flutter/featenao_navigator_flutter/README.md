# featenao_navigator_flutter

Modular, type safe and scoped navigation for Festenao apps, on top of
[go_router](https://pub.dev/packages/go_router) and
[riverpod](https://pub.dev/packages/flutter_riverpod).

Implements `packages_flutter/specs_festenao_navigator.md`.

```dart
import 'package:featenao_navigator_flutter/featenao_navigator_flutter.dart';
```

The facade re-exports go_router, so an app importing it does not need to
import go_router itself.

## Feature packages contribute routes (`FeatureRouteModule`)

A feature package declares its routes and exposes its path definitions; it
never imports another feature package nor hardcodes a location.

```dart
class SchoolRouteModule implements FeatureRouteModule {
  @override
  String get moduleId => 'school';

  @override
  List<RouteBase> get routes => [schoolListPath.goRoute(builder: ...)];
}
```

## The app assembles and overrides them (`ModularRouteResolver`)

```dart
var routes = ModularRouteResolver.assembleRoutes(
  baseModules: [SchoolRouteModule(), AuthRouteModule()],
  customOverrides: [
    // Replaces the module route named 'school_list', in place.
    RoutePathDef.parse('/school', name: 'school_list')
        .goRoute(builder: (context, state) => const MySchoolsScreen()),
  ],
);
var router = GoRouter(routes: routes, initialLocation: '/school');
```

Override matching is deterministic:

1. when both the base route and the override are **named**, the names must be
   equal — a name never matches a different name, even on the same path;
2. otherwise the paths must be exactly equal.

Prefer naming every route: it makes overrides unambiguous. An override
matching nothing is appended, which is how an app adds its own routes.
Overrides apply to the top level of the assembled list; to change something
nested, override the route that wraps it (the override carries its own
`routes:` subtree).

## Type safe paths and relative jumps (`RoutePathDef`)

Paths are declared once by chaining `child`, so each definition knows its
parent — that is what makes nested `GoRoute` paths and parameter inheritance
work without string concatenation.

```dart
var schoolListPath = RoutePathDef.parse('/school', name: 'school_list');
var schoolPath = schoolListPath.child(':school_id', name: 'school');
var studentListPath = schoolPath.child('student', name: 'student_list');
var studentPath = studentListPath.child(':student_id', name: 'student');

studentPath.path;         // /school/:school_id/student/:student_id
studentPath.relativePath; // :student_id  (the nested GoRoute path)
studentPath.location({'school_id': '124', 'student_id': '456'});
```

`location` throws an `ArgumentError` naming the missing parameter rather than
navigating nowhere.

From a widget, navigation inherits the active path parameters:

```dart
// From /school/124/student/456, only the class id is needed.
context.goPath(clasPath, parameters: {'clas_id': '789'});

context.goDeeper('clas/789');       // append to the current location
context.goSibling('clas', count: 2); // jump sideways
context.goUp();                      // works on a deep link, unlike pop
```

## Scoped state per branch (`providerScopeShellRoute`)

Children of a shell share a `ProviderScope` built from the active route, and
that scope is disposed when the branch is left.

```dart
providerScopeShellRoute(
  overrides: (state) => [
    currentSchoolIdProvider.overrideWithValue(state.pathParameter('school_id')),
  ],
  scopeKey: (state) => state.pathParameters['school_id'],
  builder: (context, state, child) => SchoolShellLayout(child: child),
  routes: [...],
)
```

Two riverpod/go_router rules to keep in mind here:

- a provider **derived** from a scoped one must declare it in its
  `dependencies` (`@Riverpod(dependencies: [currentSchoolId])` with
  riverpod_generator), otherwise it is created in the root container and
  throws — only the scoped provider itself is overridden;
- the direct children of a **top level** shell must use `absolute: true` in
  `goRoute`, since a shell adds nothing to the location. Deeper routes nest
  normally and stay relative.

`scopeKey` decides what happens when the parameter itself changes
(`/school/124/...` → `/school/125/...`): without it the same scope is reused
and only the overridden values change; with it the scope is recreated, so
everything cached for the previous school is disposed.

A route pushed on the **root** navigator is built outside the shell subtree
and loses that scope — wrap it with `scopedFrom(context, child: ...)` to keep
the scoped providers readable.

## Testing

Route assembly and path definitions are plain Dart: they are unit tested
without pumping a widget tree (see `test/`).

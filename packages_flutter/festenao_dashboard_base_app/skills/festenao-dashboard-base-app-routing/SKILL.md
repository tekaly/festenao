---
name: festenao-dashboard-base-app-routing
description: >-
  Use when assembling or extending the go_router tree of a festenao dashboard
  app with festenao_dashboard_base_app (router.dart):
  dashboardBaseRouteModules(), DashboardContentRouteModule,
  DashboardAccessRouteModule / DashboardLogRouteModule (parentRouteName:),
  DashboardMediaRouteModule, DashboardDemoRouteModule,
  DashboardQuizzRouteModule, ModularRouteResolver.assembleRoutes with
  customOverrides, the RoutePathDefs (dashboardHomePath, dashboardProjectPath,
  dashboardProjectDataPath, contentImagesPath, contentMediasPath,
  projectsAccessPath, projectAccessPath, dashboardProjectSlugPath,
  dashboardLogsPath, blogDemoPath, quizzHomePath...), DashboardRouteParams,
  dashboardProjectScope(state, child:, dataId:) feeding
  currentProjectIdProvider / currentDataIdProvider, context.pushPath
  navigation and ContentNavigatorGoRouterBridge. Not the providers nor the
  screens themselves.
---

# festenao_dashboard_base_app routing

The dashboard screens come as `FeatureRouteModule`s (festenao_navigator_flutter)
declared from typed `RoutePathDef`s: a host app assembles them with its own
modules and overrides, once, into a `GoRouter`. Below `/project/:project_id`
the routes wrap their screen in a riverpod scope holding the ids of the
location, so the screens read `currentProjectIdProvider` instead of taking
them as arguments.

```dart
import 'package:festenao_dashboard_base_app/router.dart';

/// The router of a dashboard app, built once at startup.
final dashboardRouter = GoRouter(
  initialLocation: '/',
  routes: ModularRouteResolver.assembleRoutes(
    baseModules: dashboardBaseRouteModules(),
  ),
);
```

## Guidelines

### Assembly

* Dependency (git, not on pub.dev) and one import,
  `package:festenao_dashboard_base_app/router.dart`, which re-exports
  `festenao_navigator_flutter` and go_router (`GoRouter`, `GoRoute`,
  `RouteBase`, `GoRouterState`, `RoutePathDef`, `FeatureRouteModule`,
  `NestedFeatureRouteModule`, `ModularRouteResolver`, the `context.pushPath`
  / `goPath` extension). `package:flutter_riverpod/flutter_riverpod.dart`
  for the `ProviderScope` around `MaterialApp.router`: the screens consume
  the providers of `provider.dart` (flavor, firebase, projects db), set up
  first.
* `dashboardBaseRouteModules()` returns, in order, `DashboardContentRouteModule`
  (`/`, `/project/:project_id`, `/project/:project_id/data/:data_id` and the
  image screens below it), `DashboardAccessRouteModule` (`/projects_access`,
  `/project_access/:project_id`, `/p/:slug`), `DashboardMediaRouteModule`
  (the media screens under the data route), `DashboardDemoRouteModule`
  (`blog_demo`, `legacy_blog_demo`, `content_demo` under the project),
  `DashboardQuizzRouteModule` (`quizz`, `quizz/question_create`,
  `quizz/question/:question_id`, `quizz/quiz/:quiz_id`, `.../tv` under the
  project) and `DashboardLogRouteModule` (`/logs`). Build your own list to
  keep only some features.
* Every module but the content one is a `NestedFeatureRouteModule`: the
  resolver mounts it under the route **named** `parentRouteName`, wherever
  that route is, and throws an `ArgumentError` when no module declares the
  name. Access and log hang under `dashboardHomePath.name` (`home`) by
  default, `DashboardAccessRouteModule(parentRouteName:)` /
  `DashboardLogRouteModule(parentRouteName:)` when the root route of the app
  has another name; demo and quizz hang under `dashboardProjectPath.name`
  (`project`), media under `dashboardProjectDataPath.name` (`project_data`):
  keep a route with those names (the content module, or your own) or drop
  the modules that need them.
* Nesting is what gives a directly opened location (a page load on the web)
  its ancestor stack: `/projects_access` builds `/` below it, so there is
  always a back. Mount your own screens the same way, as nested modules
  under `home` or `project`, not at the top level.
* Override a screen with `customOverrides:`, a `GoRoute` whose `name` is the
  one of the definition (`projectsAccessPath.goRoute(builder: ...)`): it
  replaces the route in place with its own `routes:` subtree, so override
  leaves; overriding `dashboardHomePath` or `dashboardProjectPath` without
  re-declaring their children drops the whole branch. A route matching
  nothing is appended at the top level.
* Assemble once (a top level `final` or in `main`), never in `build`.

### Ids and scope

* `dashboardProjectScope(state, child:, dataId:)` wraps `child` in a
  `ProviderScope` overriding `currentProjectIdProvider` with the `project_id`
  of the location and `currentDataIdProvider` with its `data_id` when
  present, or with `dataId:` for a branch working on a fixed database (the
  blog demo on `blog`); otherwise the data id keeps its default,
  `SdbProjectContent.defaultDataId` (`content`). Use it in every route of
  your own mounting a screen below the project.
* It is a plain `ProviderScope` per page, not a `ShellRoute`: the pages of
  different modules stay on one navigator, so a push from the project home
  to a blog page can be popped. Only the two id providers are scoped;
  everything derived stays a plain family keyed by the ids
  (`artistEntriesProvider(projectId, dataId)`), no `dependencies:` lists.
* A screen reads `ref.watch<String>(currentProjectIdProvider)` (the explicit
  type argument keeps `projectId ?? ref.watch(...)` a `String`); outside a
  project branch it throws a `StateError` on purpose. The scoped screens of
  the package also accept the ids as constructor arguments, for an app that
  mounts them elsewhere.
* Parameter names: `DashboardRouteParams.projectId` (`project_id`),
  `dataId` (`data_id`), `imageId`, `mediaId`, `questionId`, `quizId`,
  `slug`; `DashboardRouter` holds the same values for the content screens.
  `state.pathParameter(DashboardRouteParams.projectId)` in a builder.

### Navigation

* `context.pushPath(contentImagesPath, parameters: {DashboardRouteParams.projectId: id, DashboardRouteParams.dataId: 'content'})`
  or `goPath`; the active path parameters are inherited, so from a project
  screen `context.pushPath(blogDemoPath)` needs none. The screens ship
  helpers doing this (`goToContentImagesScreen(context, projectId:,
  dataId:)`...). Never concatenate a location: `def.location({...})` when a
  string is needed, `dashboardProjectSlugLocation(slug)` for `/p/<slug>`.
* `DashboardHomePage` has a debug tile doing `context.pushNamed('debug')`
  in debug mode: give the app a route named `debug`.
* `ContentNavigatorGoRouterBridge(router:, child:)` installs a
  `ContentNavigatorBloc` mapping the `ContentNavigator` calls of the
  festenao_admin_base_app screens (`push`, `popToRoot`, `popUntilPathOrPush`)
  onto `router.push` / `router.go` of the content path string: useful only
  when the app declares go_router routes at those content paths.

### Tests

* The assembled tree is pure Dart: assemble, walk the `GoRoute`s and assert
  the paths and names (`test/dashboard_routes_test.dart` does it for the base
  modules). The scope is a widget test: `ProviderScope(child:
  MaterialApp.router(routerConfig: router))` with probe routes built with
  `dashboardProjectScope`, `absolute: true` when declared at the top level.

## Examples

### The app: base modules, an override and its own module

```dart
import 'package:festenao_dashboard_base_app/router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// `/about`, an app only route: matches no base route, appended.
final aboutPath = RoutePathDef.parse('/about', name: 'about');

/// `/debug`, the name the home page's debug tile pushes.
final debugPath = RoutePathDef.parse('/debug', name: 'debug');

GoRouter buildRouter() => GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: kDebugMode,
  routes: ModularRouteResolver.assembleRoutes(
    baseModules: [
      // Content, access and media only: no demo, quizz nor logs.
      DashboardContentRouteModule(),
      DashboardAccessRouteModule(),
      DashboardMediaRouteModule(),
      ProjectNotesRouteModule(),
    ],
    customOverrides: [
      // Same name as the base route: replaced in place.
      projectsAccessPath.goRoute(
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('My projects'))),
      ),
      aboutPath.goRoute(
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('About'))),
      ),
      debugPath.goRoute(
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Debug'))),
      ),
    ],
  ),
);

/// `/project/:project_id/notes`, hanging under the project route.
final projectNotesPath = dashboardProjectPath.child(
  'notes',
  name: 'project_notes',
);

class ProjectNotesRouteModule implements NestedFeatureRouteModule {
  @override
  String get moduleId => 'project_notes';

  @override
  String get parentRouteName => dashboardProjectPath.name!;

  @override
  List<RouteBase> get routes => [
    projectNotesPath.goRoute(
      // The scope gives the screen its project id.
      builder: (context, state) =>
          dashboardProjectScope(state, child: const ProjectNotesScreen()),
    ),
  ];
}

class ProjectNotesScreen extends StatelessWidget {
  const ProjectNotesScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('notes')));
}
```

### A scoped screen navigating to the base screens

```dart
import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:festenao_dashboard_base_app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mounted below `/project/:project_id` with dashboardProjectScope.
class ProjectToolsScreen extends ConsumerWidget {
  const ProjectToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var projectId = ref.watch<String>(currentProjectIdProvider);
    var dataId = ref.watch<String>(currentDataIdProvider); // 'content'
    return Scaffold(
      appBar: AppBar(title: Text('Project $projectId')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Images'),
            // project_id is inherited from the location, data_id is not.
            onTap: () => context.pushPath(
              contentImagesPath,
              parameters: {DashboardRouteParams.dataId: dataId},
            ),
          ),
          ListTile(
            title: const Text('Access'),
            onTap: () => context.pushPath(projectAccessPath),
          ),
          ListTile(
            title: const Text('All my projects'),
            onTap: () => context.goPath(projectsAccessPath),
          ),
        ],
      ),
    );
  }
}
```

### Asserting the tree

```dart
import 'package:festenao_dashboard_base_app/router.dart';
import 'package:flutter_test/flutter_test.dart';

Iterable<String> _names(List<RouteBase> routes) sync* {
  for (var route in routes) {
    if (route is GoRoute) {
      if (route.name != null) yield route.name!;
      yield* _names(route.routes);
    }
  }
}

void main() {
  test('the access routes hang under home', () {
    var routes = ModularRouteResolver.assembleRoutes(
      baseModules: [
        DashboardContentRouteModule(),
        DashboardAccessRouteModule(),
      ],
    );
    var home = routes.single as GoRoute;
    expect(home.name, dashboardHomePath.name);
    expect(
      _names(routes),
      containsAll([projectsAccessPath.name, dashboardProjectSlugPath.name]),
    );
  });
}
```

## Common mistakes

* `ArgumentError` about a missing parent route (`project_data`, `project`,
  `home`): a nested module listed without the module declaring its parent.
* `StateError: currentProjectIdProvider is only readable below a project
  route`: a scoped screen mounted without `dashboardProjectScope`.
* An overridden `dashboardHomePath` with no `routes:`: the whole project
  branch is gone, the app only has `/`.

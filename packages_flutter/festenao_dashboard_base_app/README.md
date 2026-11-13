# festenao_dashboard_base_app

The building blocks of a Festenao dashboard app (Flutter, riverpod,
go_router): the providers of the signed in user's projects and of their
synchronized content, the route modules of the dashboard screens (projects,
access and invites, project urls, images, medias, quizz, logs) and the
screens themselves. An app assembles the modules it wants, overrides a few
providers at startup, and adds its own screens next to them.

Not on pub.dev: a git dependency of the `tekaly/festenao` repository.

## Getting started

```yaml
dependencies:
  festenao_dashboard_base_app:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_dashboard_base_app
```

Three libraries, or `festenao_dashboard_base_app.dart` for all of them:

| Import | What |
|---|---|
| `provider.dart` | the riverpod providers: firebase, identity, user projects, project access, project content (`projectContentProvider`, `artistEntriesProvider`...), quizz, slugs |
| `router.dart` | the route modules (`dashboardBaseRouteModules()`), the `RoutePathDef`s, `dashboardProjectScope`; re-exports go_router and festenao_navigator_flutter |
| `screen.dart` | the screens (`DashboardHomePage`, the access, content, quizz screens) and their `goToXxxScreen` helpers |

A minimal app: firebase initialized first (`firebaseContext`), the root
`ProviderScope` with the flavor, firebase and projects overrides, then the
router of the base modules.

```dart
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_dashboard_base_app/festenao_dashboard_base_app.dart';
import 'package:festenao_riverpod_flutter/festenao_riverpod_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

/// Assembled once, never in a build method.
final router = GoRouter(
  initialLocation: '/',
  routes: ModularRouteResolver.assembleRoutes(
    baseModules: dashboardBaseRouteModules(),
  ),
);

/// [firebaseContext]: the app's firebase (flutter, rest or local).
Future<void> runDashboardApp(FirebaseContext firebaseContext) async {
  WidgetsFlutterBinding.ensureInitialized();
  var appFlavorContext = FestenaoAppFlavorContext.base(
    basePackageName: 'com.example.dashboard',
    appFlavorContext: FlavorContext.dev.toAppFlavorContext(baseAppId: 'myapp'),
  );
  globalFestenaoFirestoreDatabaseOrNull = FestenaoFirestoreDatabase(
    firebaseContext: firebaseContext,
    flavorContext: appFlavorContext.appFlavorContext,
  );
  runApp(
    ProviderScope(
      overrides: [
        ...await festenaoFlutterProviderOverrides(
          appFlavorContext: appFlavorContext,
        ),
        ...festenaoFirebaseContextOverrides(firebaseContext),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}
```

## Platforms

Flutter on the web, Linux, macOS, Windows, Android and iOS: the local
databases are sdb (IndexedDB on the web, sqflite elsewhere), set up by
`festenaoFlutterProviderOverrides` (festenao_riverpod_flutter). Firebase
comes from the app (`tekartik_firebase_*` services: flutter, rest or the
local simulator for tests and demos).

## Good to know

- Set the overrides before the first screen: reading an unset provider
  throws. `rpdFirestoreProvider` and `rpdFirebaseStorageProvider` return
  the `.instance` of the default (latest) Firebase app.
- Navigate with the `RoutePathDef`s (`context.pushPath(def, parameters:)`)
  or the `goToXxxScreen` helpers, never by concatenating a location: an id
  holding `/`, `?` or `#` must stay one segment.
- `projectContentProvider(projectId, dataId)` waits for the project to be
  in the local projects database of the user; a content that cannot open
  puts the provider in error.
- The screens are on `material_ui` (Flutter 3.50 deprecates
  `package:flutter/material.dart`).
- The local databases are sdb (idb_shim): start new local data on sdb too.

## Learn more

The agent skills in `skills/` hold the details, with compiled examples:

- `festenao-dashboard-base-app-providers`: the root overrides and every
  provider;
- `festenao-dashboard-base-app-routing`: assembling, overriding and
  extending the routes, the id scope, navigation, tests;
- `festenao-dashboard-base-app-screens`: the screens, their helpers and
  how to replace one.

`example/demo` is an in-memory demo of the festenao explorers and cms
screens, no Firebase project needed (see its README: its platform folders
are created first).

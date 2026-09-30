---
name: festenao-admin-base-app-setup
description: >-
  Use when running or embedding the festenao admin app with
  festenao_admin_base_app: festenaoRunAdminApp / festenaoAdminAppInit /
  FestenaoAdminApp (run.dart) with appFlavorContext, packageName,
  firebaseContext, FestenaoAppOptions (multiProjects / singleProject),
  singleProjectId, contentNavigatorDef, wrapperBuilder,
  localizationsDelegates; the firebase contexts
  initFestenaoFirebaseServicesLocal, initFestenaoAdminFirebaseContextLocalSdb,
  initFestenaoAdminFirebaseFlutter, festenaoInitFirebaseSim and
  firebase/firebase_io.dart; the ContentNavigator pages (festenaoAdminAppPages,
  ContentPageDef, route/route_paths.dart, festenaoUseContentPathNavigation);
  l10n (festenaoAdminAppAllLocalizationsDelegates, festenaoAdminAppIntl); the
  prefs (globalPrefs, currentAppId), the debug menu festenaoAdminDebugScreen
  and the lib/main_*.dart entry points. Not the data access nor the screen
  widgets.
---

# festenao_admin_base_app setup

`festenao_admin_base_app` is the base of the festenao admin apps: the
screens editing the artists, events, infos, images, medias and exports of a
project, the project and user management, on top of the tkcms admin app.
An app gives it a firebase context and a flavor and calls
`festenaoRunAdminApp`; everything else (local databases, prefs, file
system, project blocs) is set up by `festenaoAdminAppInit` into globals.
Its `lib/main*.dart` are the package's own development entry points.

```dart
import 'package:festenao_admin_base_app/firebase/firebase_local.dart';
import 'package:festenao_admin_base_app/run.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:tekartik_app_flutter_sembast/sembast.dart';

/// Everything local: a sembast backed firebase, no network.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var appFlavorContext = AppFlavorContext.testLocal;
  var firebaseContext = await initFestenaoFirebaseServicesLocal(
    sembastDatabaseFactory: getDatabaseFactory(
      rootPath: join('.local', 'my_admin', appFlavorContext.uniqueAppName),
    ),
  );
  await festenaoRunAdminApp(
    appFlavorContext: appFlavorContext,
    firebaseContext: firebaseContext,
  );
}
```

## Guidelines

### Running

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    festenao_admin_base_app:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_admin_base_app
  ```
* `festenaoRunAdminApp({appFlavorContext, firebaseContext, packageName,
  options, singleProjectId, contentNavigatorDef, wrapperBuilder,
  localizationsDelegates, supportedLocales, parentAppController})` calls
  `festenaoAdminAppInit` then `runApp(FestenaoAdminApp(...))`, wrapped by
  `wrapperBuilder` when given (a `ProviderScope`, a `Banner`), and hides
  the web splash 300 ms later. `festenaoAdminAppInit` alone initializes
  without running (embedding, tests) and returns `FestenaoAppInitResult`
  (`packageName`). `festenaoRunApp` and `festenaoRunAdminAppSingleProject`
  are older spellings of the same call.
* What init does, in order: `webSplashReady`, `packageName` defaulting to
  `festenao.admin_base_app<.flavor>`, `initFestenaoLocalSembastFactory`
  (`globalSembastDatabaseFactory`, rooted at `.dart_tool/festenao_local` on
  desktop), the prefs (`prefs_<packageName>.db`, `globalPrefs`; a saved
  `currentAppId` overrides the flavor's app id), `FestenaoFirestoreDatabase`
  (`globalFestenaoFirestoreDatabaseOrNull`, `gFsDatabaseService`),
  `globalTkCmsAdminAppFirebaseContext`, `AppAuthBloc` and
  `TkCmsAuthBloc.local` (unless `options` is given), `globalFs` (the app
  documents directory sandboxed under `uniqueAppName`),
  `globalFestenaoAppFirebaseContext` (root paths `app/<appId>` or the
  options' collection path, bucket from the firebase options or
  `<appId>.appspot.com`), `globalProjectsDb` (`<firebaseProjectId>-projects.db`),
  `globalProjectsDbBloc` (`MultiProjectsDbBloc`, `EnforcedSingleProjectDbBloc`
  with `singleProjectId`, `SingleCompatProjectDbBloc` with the single
  project option), `initFestenaoFsBuilders`, `initFestenaoDbBuilders`.
  The globals are assigned with `??=`: set one before init to override it.
* Flavor: `AppFlavorContext` (`tkcms_common/tkcms_flavor.dart`, exported by
  `festenao_common/festenao_flavor.dart`): `AppFlavorContext.testLocal` /
  `.test` for development, `tkCmsFlavorContextFromUri(Uri.base)
  .toAppFlavorContext(baseAppId: 'myapp')` (app id `myapp-dev` /
  `myapp-prod`) or `FlavorContext.dev.toAppFlavorContext(appId:)` for a
  deployment; `uniqueAppName` names the local files,
  `ifNotProdFlavorExtension` (`.dev`) suffixes the package name.
* Firebase context, one of: `initFestenaoFirebaseServicesLocal(sembastDatabaseFactory:,
  projectId:)` (sembast files, `firebase/firebase_local.dart`),
  `initFestenaoAdminFirebaseContextLocalSdb(sdbFactory:, projectId:)`
  (sdb, sets the basic auth ui), `festenaoInitFirebaseSim()`
  (`festenao_common/firebase/firebase_sim.dart`, the firebase sim server),
  `festenaoInitFirebaseIoWithServiceAccount` /
  `festenaoInitFirebaseRestIoWithServiceAccount`
  (`firebase/firebase_io.dart`, desktop tools) and
  `initFestenaoAdminFirebaseFlutter(firebaseAppOptions:)`
  (`firebase/firebase_flutter.dart`: the flutter plugins, indexeddb auth
  persistence on the web, sets `FirebaseUiAuthServiceFlutter`); that file
  imports `tekartik_firebase_flutter`, `tekartik_firebase_auth_flutter`,
  `tekartik_firebase_firestore_flutter`, `tekartik_firebase_storage_flutter`
  and `tekartik_firebase_flutter_ui_auth`, which the app must list.
  A local or service account context has admin credentials: the identity is
  a service account, no sign in screen is shown.
* Options: `FestenaoAppOptions(multiProjects: FestenaoAppMultiProjectsOptions(projectCollectionRef:))`
  manages the projects of another collection (`fsProjectCollectionInfo.copyWith(id:
  'top_project', name:).ref()`); `FestenaoAppOptions(singleProject:
  FestenaoAppSingleProjectOptions(...))` is the compat mode of the old
  single database apps; `singleProjectId:` keeps the multi project setup
  but enforces one project (the start screen offers "Main project"). With
  `options` set, no app level `AppAuthBloc` is created.

### Navigation, l10n, debug

* `FestenaoAdminApp` is a `ContentNavigator` (`tekartik_app_navigator_flutter`)
  driving a `MaterialApp.router` with the tkcms `themeData1()`. The pages are
  `ContentPageDef(path: <ContentPath>, screenBuilder: (crps) => widget)`;
  `festenaoAdminAppPages` lists the shipped ones: start (`/`, `home`,
  `festenao_home`), `projects`, `app_users`, `admin_project/<id>`,
  `project/<id>` (root) and its `metas`, `infos`, `info/<id>`, `artists`,
  `artist/<id>`, `images`, `image/<id>`, `medias`, `media/<id>`, `events`,
  `event/<id>`, `exports`, `export/<id>`, `users`, `user/<id>`
  (`route/route_paths.dart`: `RootSyncedProjectContentPath`,
  `ProjectArtistsContentPath`...). Pass `contentNavigatorDef:
  ContentNavigatorDef(defs: [...festenaoAdminAppPages, myPageDef])` to add
  pages. Two defs matching the same path fail an assert in debug mode: to
  replace a shipped page, build the list without its def.
* `festenaoUseContentPathNavigation = false` makes the `goToXxxScreen`
  helpers push plain `MaterialPageRoute`s instead of content paths (no url
  in the browser).
* l10n: the `MaterialApp` gets `festenaoAdminAppAllLocalizationsDelegates`
  (firebase ui auth basic, this package's `AppLocalizations` in en and fr,
  the tkcms admin app, the global material ones) and
  `festenaoAdminAppSupportedLocales`; when overriding them include the
  defaults. `festenaoAdminAppIntl(context)` gives the strings
  (`projectAccessAdmin`, `editUnsavedChangesTitle`, `nameLabel`...); the
  `lib/l10n/*.dart` files are generated from `l10n.yaml`, do not edit them.
* Debug: `festenaoAdminDebugScreen = muiScreenWidget('My debug', () {...})`
  before running replaces the screen behind the start screen's Debug tile
  (debug mode only); `festenaoAdminDebugScreenDefault` is the shipped one
  (users, projects db, auth, explorers, app id switch).
* Prefs: `globalPrefs.currentAppId` (needs a restart), `currentProjectId`
  (`prefs/local_prefs.dart`).
* Legacy: `admin_app/app_compat.dart` (`initAndRunFestenaoAdminApp(fbContext:,
  packageName:, parentAction:)`) and `firebase/firebase_compat.dart`
  (`initFirebaseV2FromV1`) serve the apps still on the v1 `FbContext`; new
  code uses `festenaoRunAdminApp`.

## Examples

### A deployed admin app on the flutter firebase plugins

```dart
import 'package:festenao_admin_base_app/admin_app/menu.dart';
import 'package:festenao_admin_base_app/firebase/firebase_flutter.dart';
import 'package:festenao_admin_base_app/route/navigator_def.dart';
import 'package:festenao_admin_base_app/run.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

/// `/tools`, a page of the app.
class ToolsContentPath extends ContentPathBase {
  final _part = ContentPathPart('tools');

  @override
  List<ContentPathField> get fields => [_part];
}

final toolsPageDef = ContentPageDef(
  path: ToolsContentPath(),
  screenBuilder: (crps) => Scaffold(appBar: AppBar(title: const Text('Tools'))),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var flavorContext = tkCmsFlavorContextFromUri(Uri.base);
  var appFlavorContext = flavorContext.toAppFlavorContext(baseAppId: 'myfest');
  var firebaseContext = await initFestenaoAdminFirebaseFlutter(
    firebaseAppOptions: FirebaseAppOptions(
      projectId: 'myfest-${flavorContext.flavor}',
      apiKey: 'AIza...',
      appId: '1:123:web:abc',
      storageBucket: 'myfest-${flavorContext.flavor}.appspot.com',
    ),
  );
  festenaoAdminDebugScreen = muiScreenWidget('My debug', () {
    muiItem('Say hi', () async {
      await muiSnack(muiBuildContext, 'hi');
    });
  });
  await festenaoRunAdminApp(
    appFlavorContext: appFlavorContext,
    firebaseContext: firebaseContext,
    packageName:
        'com.example.myfest.admin${appFlavorContext.ifNotProdFlavorExtension}',
    contentNavigatorDef: ContentNavigatorDef(
      defs: [...festenaoAdminAppPages, toolsPageDef],
    ),
    wrapperBuilder: (child) => flavorContext.isProd
        ? child
        : Banner(
            message: flavorContext.flavor,
            location: BannerLocation.topStart,
            child: child,
          ),
  );
}
```

### Init only, the admin app inside the app's own widget tree

```dart
import 'package:festenao_admin_base_app/run.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:flutter/material.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

Future<void> runEmbedded({
  required FirebaseContext firebaseContext,
  required AppFlavorContext appFlavorContext,
}) async {
  var result = await festenaoAdminAppInit(
    appFlavorContext: appFlavorContext,
    firebaseContext: firebaseContext,
    // The app id has one project: the start screen offers it directly.
    singleProjectId: 'main',
  );
  debugPrint('admin ready as ${result.packageName}');
  // FestenaoAdminApp builds its own MaterialApp.router.
  runApp(const FestenaoAdminApp());
}
```

### The projects of another collection

```dart
import 'package:festenao_admin_base_app/run.dart';
import 'package:festenao_common/app/app_options.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

final topProjectCollectionInfo = fsProjectCollectionInfo.copyWith(
  id: 'top_project',
  name: 'Top Project',
);

Future<void> runTopProjects(FirebaseContext firebaseContext) =>
    festenaoRunAdminApp(
      firebaseContext: firebaseContext,
      appFlavorContext: FlavorContext.dev.toAppFlavorContext(
        appId: 'festenao_top_projects',
      ),
      options: FestenaoAppOptions(
        multiProjects: FestenaoAppMultiProjectsOptions(
          projectCollectionRef: topProjectCollectionInfo.ref(),
        ),
      ),
    );
```

### Local sdb firebase with a sign in screen

```dart
import 'package:festenao_admin_base_app/firebase/firebase_local_sdb.dart';
import 'package:festenao_admin_base_app/run.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:flutter/material.dart';
import 'package:idb_shim/sdb.dart';

/// In memory: a fresh app every start, the basic auth ui installed.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseContext = await initFestenaoAdminFirebaseContextLocalSdb(
    sdbFactory: sdbFactoryMemory,
    projectId: 'my-admin-local',
  );
  await festenaoRunAdminApp(
    appFlavorContext: AppFlavorContext.testLocal,
    firebaseContext: firebaseContext,
  );
}
```

## Common mistakes

* `Null check operator used on a null value` from `goToAuthScreen`:
  `globalAuthFlutterUiService` never set; use one of the inits that set it,
  or assign `FirebaseUiAuthServiceBasic()` / `FirebaseUiAuthServiceFlutter()`
  yourself (`auth/auth.dart`).
* Two apps sharing prefs and databases: same `packageName` and flavor;
  give each app its own package name, with the flavor extension.
* Changing `currentAppId` from the debug menu and seeing no change: it is
  read at init, restart the app.

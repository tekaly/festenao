# festenao_admin_base_app

The base of the older festenao admin apps (Flutter): the screens editing the
content of a festival project (artists, events, infos, images, medias,
metas, forms, exports and their publication), the apps, projects and users
management, on top of the tkcms admin app. An app gives it a firebase
context and a flavor and calls `festenaoRunAdminApp`; the rest (local
databases, prefs, file system, project blocs) is set up into globals.

**Legacy**: the screens are blocs on a `ContentNavigator`, the local data a
sembast `ProjectsDb` / `DbProject` and one synced sembast content database
per project. A new admin app starts on `festenao_dashboard_base_app`
(riverpod, go_router, sdb).

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  festenao_admin_base_app:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_admin_base_app
```

Everything local, no network (a sembast backed firebase, signed in as a
service account):

```dart
import 'package:festenao_admin_base_app/firebase/firebase_local.dart';
import 'package:festenao_admin_base_app/run.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart';
import 'package:tekartik_app_flutter_sembast/sembast.dart';

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

A deployed app passes `initFestenaoAdminFirebaseFlutter(firebaseAppOptions:)`
(`firebase/firebase_flutter.dart`, the Flutter firebase plugins, a sign in
screen) and a dev or prod flavor; see the setup skill.

Platforms: Android, iOS, the web, macOS, Linux and Windows. The local
databases go to `.dart_tool/festenao_local` on desktop, the browser storage
on the web.

## What to know

- `festenaoAdminAppInit` (called by `festenaoRunAdminApp`) assigns globals
  with `??=`: set one before to override it. Call it once.
- A local or service account firebase context is an admin: no sign in
  screen. With the Flutter plugins, the user signs in and sees the projects
  their access documents grant.
- The project content (artists, events...) is a synced database per project:
  the screens grab it through a `FestenaoAdminAppProjectContext` and release
  it when they close.
- The screens are in English and French (`festenaoAdminAppAllLocalizationsDelegates`,
  set by default; an app overriding `localizationsDelegates` includes them).
- `lib/main*.dart` are the package's own development entry points.

## Skills

- `festenao-admin-base-app-setup`: running and embedding the app, the
  firebase contexts, navigation, l10n, prefs.
- `festenao-admin-base-app-auth-data`: the identity, the firebase globals,
  the local projects database, the content database of a project.
- `festenao-admin-base-app-screens`: the screens and how to open them.

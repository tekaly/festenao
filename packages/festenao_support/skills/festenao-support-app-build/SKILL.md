---
name: festenao-support-app-build
description: >-
  Use when building or deploying a festenao flutter web app from a support
  tool with festenao_support: FestenaoFirebaseAppBuilder and
  FestenaoFirebaseAppBuildOptions (projectId, baseHostingId, the per flavor
  hosting id and deploy target), its devWebAppBuilder / prodWebAppBuilder,
  menuFestenaoFirebaseAppBuilder and the menuFirebaseAppContent build/deploy
  menu it wraps.
---

# festenao_support app build

A festenao flutter web app is deployed per flavor to one firebase project:
`prod` gets the base hosting id, every other flavor gets it suffixed
(`-dev`). `FestenaoFirebaseAppBuilder` holds that naming rule once, and hands
out a ready `FlutterFirebaseWebAppBuilder` per flavor, which the build menu
turns into build and deploy items.

## Guidelines

* Import `package:festenao_support/festenao_build_menu_flutter.dart`: it
  re-exports the dev menu, `tekartik_build_menu_flutter`, the firebase deploy
  options and the firebase app build menu, plus
  `FestenaoFirebaseAppBuilder`, `FestenaoFirebaseAppBuildOptions`,
  `FestenaoFirebaseAppFlavorBuildOptions` and
  `menuFestenaoFirebaseAppBuilder`. Never import `src/`.
* `FestenaoFirebaseAppBuildOptions(projectId:, baseHostingId:)` is the
  naming: the firebase project every flavor deploys to, and the hosting id of
  `prod`. A non prod flavor appends `-<flavor>`
  (`ifNotProdHostingIdSuffix`), so `my-app` gives `my-app-dev` on `dev`.
* `FestenaoFirebaseAppBuilder(options:, path:)` — `path` is the flutter app
  package. `webAppBuildOptions` is `FlutterWebAppBuildOptions(wasm: true)`:
  festenao web apps build to wasm.
* `devWebAppBuilder` and `prodWebAppBuilder` are the per flavor
  `FlutterFirebaseWebAppBuilder`s, each carrying its
  `FirebaseDeployOptions(projectId:, hostingId:, target:)` — the deploy
  target is the flavor name, so the `firebase.json` hosting targets must
  match.
* `menuFestenaoFirebaseAppBuilder(builder:)` adds a `web dev` menu holding
  both builders through `menuFirebaseAppContent(builders: [...])` — build,
  serve and deploy items for each. Declare it inside `mainMenuConsole`.
* One builder per app, in the support package of the project, next to the
  other menus (`festenao-support-dev-menu`): the tool is where the deploy
  happens, never the app package.
* A deploy is the deploy of a build: build the flavor first, then deploy it.
  The menu items are in that order for that reason.

## Examples

### The build menu of an app

```dart
/// The build menu of the app: `dart run tool/menu.dart`.
library;

import 'package:festenao_support/festenao_build_menu_flutter.dart';

final userAppBuilder = FestenaoFirebaseAppBuilder(
  path: '../../packages_flutter/my_user_app',
  options: const FestenaoFirebaseAppBuildOptions(
    projectId: 'my-app-dev',
    // prod: my-app, dev: my-app-dev
    baseHostingId: 'my-app',
  ),
);

Future<void> main(List<String> args) async {
  mainMenuConsole(args, () {
    menu('user app', () {
      menuFestenaoFirebaseAppBuilder(builder: userAppBuilder);
    });
  });
}
```

### Several apps in one menu

```dart
import 'package:festenao_support/festenao_build_menu_flutter.dart';

FestenaoFirebaseAppBuilder _app(String path, String hostingId) =>
    FestenaoFirebaseAppBuilder(
      path: path,
      options: FestenaoFirebaseAppBuildOptions(
        projectId: 'my-app-dev',
        baseHostingId: hostingId,
      ),
    );

Future<void> main(List<String> args) async {
  var apps = {
    'user app': _app('../../packages_flutter/my_user_app', 'my-app'),
    'admin app': _app('../../packages_flutter/my_admin_app', 'my-app-admin'),
  };
  mainMenuConsole(args, () {
    for (var entry in apps.entries) {
      menu(entry.key, () {
        menuFestenaoFirebaseAppBuilder(builder: entry.value);
      });
    }
  });
}
```

### The builders alone, without the menu

```dart
import 'package:festenao_support/festenao_build_menu_flutter.dart';

/// Builds and deploys the dev web app (what the menu items run).
Future<void> deployDev(FestenaoFirebaseAppBuilder builder) async {
  await builder.devWebAppBuilder.build();
  await builder.devWebAppBuilder.deploy();
}
```

## Common mistakes

* Giving `baseHostingId` the dev hosting id: it is the `prod` one, the flavor
  suffix is added for the others, and `my-app-dev` would deploy dev to
  `my-app-dev-dev`.
* A `firebase.json` without the hosting target of the flavor: the deploy
  options name a target (`dev`, `prod`), and the firebase cli refuses an
  unknown one.
* Deploying without building the same flavor first: the previous build is
  what goes out.
* Pointing `path` at the support package instead of the flutter app: the
  build runs in the wrong directory.

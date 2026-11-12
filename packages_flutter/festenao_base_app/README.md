# festenao_base_app

The base of the older festenao user apps (Flutter), the ones that show the
**published** data of a project without signing in:

- `db/festenao_db_compat.dart`: `initWithAssetAndStorage` loads the project
  export (bundled assets, then the public storage bucket) into a local
  sembast `FestenaoDb`, and `initData` turns it into in memory objects
  (`appGetAllEvents()`, `appGetArtistById(id)`, `appInfos`, the playlists...).
- `view/`: `ImageWidget` (an image of the export, asset or storage, with its
  blur hash), `ScaffoldWithParentAction`.
- `form/`: form and survey player screens (start, questions, end) over a
  festenao_common `TkFormPlayer`.
- Boot helpers: `url_strategy/url_strategy.dart`, `web_splash/web_splash.dart`,
  `import/ui.dart` (mini ui), `blurhash/flutter_blurhash.dart`.

**Legacy**: the data layer is the sembast `FestenaoDb` kept for the existing
apps; new code reads its data through sdb (festenao_common
`festenao_sdb.dart`, `FestenaoSyncedSdb`).

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  festenao_base_app:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_base_app
```

```dart
import 'package:festenao_base_app/db/festenao_db_compat.dart';
import 'package:festenao_base_app/web_splash/web_splash.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  webSplashReady();
  WidgetsFlutterBinding.ensureInitialized();
  // The bundled export first (assets/data), then the public storage.
  await initWithAssetAndStorage(
    packageName: 'com.example.myfest',
    projectId: 'myfest-prod',
    storageBucket: 'myfest-prod.appspot.com',
    storageRootPath: 'app/myfest',
  );
  runApp(
    MaterialApp(
      home: Scaffold(body: Text('${appGetAllEvents().length} events')),
    ),
  );
  webSplashHide();
}
```

Platforms: Android, iOS, the web, macOS, Linux and Windows (sembast through
`tekartik_app_flutter_sembast`).

## What to know

- Everything is global and synchronous once `initWithAssetAndStorage`
  returned: build no screen before (`LateInitializationError`).
- The storage import does not call `initData` again: call
  `await initData(festenaoDb)` after it (or at the next start) to show the
  fresh data; each call rebuilds every map.
- The form screens are imported by file (`form/src/screen/...`); their texts
  are French; the shipped end screen does not store nor send the answers
  (read them from the player in your own end screen).

The package skills have the details and examples:
`skills/festenao-base-app-user-app` (boot, data, widgets) and
`skills/festenao-base-app-form-player` (the form screens).

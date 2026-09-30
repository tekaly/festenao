---
name: festenao-base-app-user-app
description: >-
  Use when building or maintaining a festenao user app that ships the
  published data of a project without firebase auth, on festenao_base_app:
  the boot facades (url_strategy/url_strategy.dart setPathUrlStrategy,
  web_splash/web_splash.dart webSplashReady / webSplashHide, import/ui.dart
  mini ui, blurhash/flutter_blurhash.dart BlurHash), the compat data layer of
  db/festenao_db_compat.dart (initWithAssetAndStorage, initData, festenaoDb,
  FesteanoAppDbDataContext, AppArticle / AppArtist / AppEvent / AppInfo /
  AppLocation, appGetAllArtist, appGetAllEvents, appGetArtistById,
  appGetEventById, appGetInfoById, appGetLocationById,
  appGetArticleByKindAndId, appInfos, appEvents, appLocations, dbImages,
  appPlayerPlaylists, AppPlayerPlayList / AppPlayerSong,
  gAppAssetDataImgList, isTargetDev), the storage context (AppDataContext,
  appDataContext, appProjectId, appStorageRootPath),
  view/image_widget_compat.dart ImageWidget and
  view/parent_action_scaffold.dart ScaffoldWithParentAction. Not the form
  player screens.
---

# festenao_base_app user app

`festenao_base_app` is the base of the festenao user apps that read the
**published** data of a project: an export bundled as assets, refreshed from
the public storage bucket, loaded into a local sembast `FestenaoDb` and
turned into in memory `App*` objects the screens read synchronously. No
firebase auth, no api: the app only knows the project id, the bucket and the
storage root path of the project.

```dart
import 'package:festenao_base_app/db/festenao_db_compat.dart';
import 'package:festenao_base_app/web_splash/web_splash.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  webSplashReady();
  WidgetsFlutterBinding.ensureInitialized();
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

## Guidelines

### Boot

* Dependency (git, not on pub.dev). The compat data layer imports
  `tekartik_app_flutter_sembast` (`getDatabaseFactory`) without depending on
  it, so the app lists it too:
  ```yaml
  dependencies:
    festenao_base_app:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_base_app
    tekartik_app_flutter_sembast:
      git:
        url: https://github.com/tekartik/app_flutter_utils.dart
        path: app_sembast
  ```
* Order in `main`: `webSplashReady()`, `setPathUrlStrategy()` on the web
  (`package:festenao_base_app/url_strategy/url_strategy.dart`),
  `WidgetsFlutterBinding.ensureInitialized()`, `await
  initWithAssetAndStorage(...)`, `runApp`, `webSplashHide()`. The splash
  needs the `app_splash` markup of `tekartik_web_splash` in `index.html`.
* `initWithAssetAndStorage({packageName, projectId, storageBucket,
  storageRootPath, useFestenaoDb, dev})`, in this order:
  1. opens `FestenaoDb` through `initDatabaseFactory(packageName:)` (on
     desktop the file lands under `.dart_tool/tradhiv2022`, a hardcoded
     root path);
  2. unless `useFestenaoDb` is given, syncs the bundled export
     (`assetsDataExportPath` = `assets/data/festenao_export.jsonl`,
     `assetsDataExportMetaPath` = `assets/data/festenao_export_meta.json`)
     with `FestenaoAppSyncExport`; a missing asset only prints in debug;
  3. `initData(festenaoDb)` fills the globals;
  4. imports the newer export from the bucket,
     `<storageRootPath>/data/festenao_export_meta[_dev].json`
     (`storageDataDirPart`), `dev` defaulting to `isTargetDev`
     (`tkCmsFlavorContextFromUri(Uri.base).isDev`, the flavor of the page
     url); a failure is printed and ignored;
  5. sets `appDataContext = AppDataContext(projectId:, rootPath:)`, which
     `ImageWidget` needs.
  The storage import does **not** call `initData` again: to show the fresh
  data the app calls `await initData(festenaoDb)` after init, or restarts.
* Assets: list `assets/data/` and `assets/data/img/` in the pubspec;
  `gAppAssetDataImgList` is the list of image basenames found there
  (`getAssetList()` scans the asset manifest), `assetsDataImagePath` the
  folder.
* `useFestenaoDb:` reuses a database already open (the admin app opening the
  user app on its own data, with `ScaffoldWithParentAction(parentAction:)`
  showing the back button): the asset sync is skipped, the storage import
  still runs.

### Data

* Everything is global, filled by `initData`: `appInfos`, `appEvents`,
  `appLocations` (maps by id), `dbImages` (`DbImage` by id),
  `appPlayerPlaylists`, `gAppAssetList`; artists are behind
  `appGetArtistById` / `appGetAllArtist()` (their map is `@protected`).
  `appGetAllArtist()` and `appGetAllEvents()` drop the hidden articles and
  sort (artists by id, events by day then begin time); the `appGetXxxById`
  return hidden ones too.
* `AppArticle` wraps a `DbArticle`: `id`, `kind` (`AppArticleKind.artist /
  event / info / location`), `dbArticle`, `hasTag`, `hidden`, `cancelled`,
  `inProgress` (from the tags), `thumbnail` and `mainImageId` (image ids
  linked by `initData` from the image ids `<kind>_thumbnail_<id>`,
  `<kind>_main_<id>` or the compat `<kind>_<id>`, `appGetArticlePrefix`
  giving the kind prefix). `AppArticleExt` gives `name`, `subtitle`,
  `content`, `type`, `attributes`, trimmed (an empty string is null).
* `AppEvent`: `day` (`CalendarDay`), `startTime`, `startDayTime`,
  `timeText`, `location` (an `AppLocation` from the location attribute),
  `artists` (from the artist attributes, else the artist with the event's
  id), `artist` when exactly one. `AppArtist.events` and `singleEvent` are
  the reverse links. `AppLocation` is a `DbInfo` of `type`
  `infoTypeLocation`; every info, locations included, is also in `appInfos`.
* Player: an info of type `infoTypePlaylist` becomes an `AppPlayerPlayList`
  (`title`, `songs`, `id`); its songs are the attributes whose value is
  `info:<songId>`, pointing to an info of type `infoTypeSong`
  (`AppPlayerSong`: `title`, `subtitle`, `author`, `urls` from the
  `attributeTypeAudio` attributes, `index` in the playlist).
  `AppPlayerCvAttributeExtension` (`isInfo`, `isSong`, `song`) and
  `AppPlayerAppInfoExtension` (`isSong`, `isPlaylist`) do the lookup.
* `festenaoUserDb` is declared `late` here and never assigned by this
  package: an app using it opens its own `FestenaoUserDb` and sets it.

### Widgets

* `ImageWidget(image: dbImage, noBlurHash:)`: an `AspectRatio` of the image
  size, the `BlurHash` placeholder, then the asset when the name is in
  `gAppAssetDataImgList`, else the network image at
  `getUnauthenticatedStorageApi(projectId: appProjectId).getMediaUrl('<appStorageRootPath>/image/<name>')`.
  It reads `appDataContext`: only valid after `initWithAssetAndStorage`.
* `package:festenao_base_app/firebase/firebase_compat.dart` is a second,
  independent copy of `AppDataContext` / `appDataContext` / `appProjectId`:
  setting that one does not feed `ImageWidget`, which reads the copy
  `initWithAssetAndStorage` fills. Let init set it.
* `package:festenao_base_app/import/ui.dart` is the mini ui
  (`muiScreenWidget`, `muiItem`, `muiSnack`...),
  `blurhash/flutter_blurhash.dart` re-exports `flutter_blurhash`.

## Examples

### Events with their artist, location and thumbnail

```dart
import 'package:festenao_base_app/db/festenao_db_compat.dart';
import 'package:festenao_base_app/view/image_widget_compat.dart';
import 'package:flutter/material.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Visible events, sorted by day and begin time.
    var events = appGetAllEvents();
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        var event = events[index];
        var thumbnailId = event.thumbnail;
        var thumbnail = thumbnailId == null ? null : dbImages[thumbnailId];
        return ListTile(
          leading: thumbnail == null
              ? null
              : SizedBox(width: 56, child: ImageWidget(image: thumbnail)),
          title: Text(event.name ?? event.id),
          subtitle: Text(
            '${event.day} ${event.timeText}'
            '${event.location == null ? '' : ' - ${event.location!.name}'}'
            '${event.artist == null ? '' : ' - ${event.artist!.name}'}',
          ),
          trailing: event.cancelled ? const Icon(Icons.cancel) : null,
        );
      },
    );
  }
}
```

### Refreshing the globals after the storage import

```dart
import 'package:festenao_base_app/db/festenao_db_compat.dart';

/// Init imports the newer export after filling the globals: rebuild them.
Future<void> initAppData() async {
  await initWithAssetAndStorage(
    packageName: 'com.example.myfest',
    projectId: 'myfest-prod',
    storageBucket: 'myfest-prod.appspot.com',
    storageRootPath: 'app/myfest',
    dev: false,
  );
  await initData(festenaoDb);
}
```

### Playlists, songs and lookups

```dart
import 'package:festenao_base_app/db/festenao_db_compat.dart';

/// The audio urls of every playlist, by title.
Map<String, List<String>> playlistUrls() => {
  for (var playlist in appPlayerPlaylists.values)
    playlist.title ?? playlist.id: [
      for (var song in playlist.songs) ...song.urls,
    ],
};

/// The artist of an event page, or null (hidden ones included).
AppArtist? eventArtist(String eventId) => appGetEventById(eventId)?.artist;

/// Any article from a link `<kind>/<id>`.
AppArticle? articleFromLink(AppArticleKind kind, String id) =>
    appGetArticleByKindAndId(kind, id);
```

### Opened from the admin app on its database

```dart
import 'package:festenao_base_app/db/festenao_db_compat.dart';
import 'package:festenao_base_app/view/parent_action_scaffold.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:flutter/material.dart';

/// The admin app hands its own [FestenaoDb]; the asset sync is skipped.
Future<void> runOnAdminDb(FestenaoDb db, VoidCallback backToAdmin) async {
  await initWithAssetAndStorage(
    packageName: 'com.example.myfest.admin',
    projectId: 'myfest-dev',
    storageBucket: 'myfest-dev.appspot.com',
    storageRootPath: 'app/myfest',
    useFestenaoDb: db,
  );
  runApp(
    MaterialApp(
      home: ScaffoldWithParentAction(
        appBar: AppBar(title: const Text('Preview')),
        parentAction: backToAdmin,
        body: Text('${appGetAllArtist().length} artists'),
      ),
    ),
  );
}
```

## Common mistakes

* `LateInitializationError` on `appDataContext` or `gAppAssetDataImgList`:
  a screen built before `initWithAssetAndStorage` returned, or
  `ImageWidget` used by a tool that only opened the database.
* Empty lists on a fresh install: no export in `assets/data/` and no
  network; bundle the export, or show a loading state until `initData`.
* Setting `appDataContext` through `firebase/firebase_compat.dart` and
  getting a `LateInitializationError` from `ImageWidget`: two copies, see
  Widgets.

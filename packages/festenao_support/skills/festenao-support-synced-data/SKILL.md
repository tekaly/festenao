---
name: festenao-support-synced-data
description: >-
  Use when exporting festenao synced data to an app's assets, or reading it
  back, with festenao_support: buildData (the incremental assets build:
  FestenaoSourceFirestore and FestenaoDbSourceSync down to a SyncedDb, the
  festenao_export.jsonl and festenao_export_meta.json pair, the img/ files)
  and FestenaoExportLocalBuilder (exportLocal / importLocal of a folder,
  storageBuildData, firestoreBuildData).
---

# festenao_support synced data

An app that ships its content reads it from its assets, not from firestore: a
support tool syncs the festenao database down with a service account, exports
it as jsonl next to the images, and the app opens that export as its local
database. `buildData` is the whole round trip, incremental — it imports the
previous export, syncs what changed since, and writes it back.

## Guidelines

* Import `package:festenao_support/festenao_synced_data.dart`: it exports
  `buildData` and `FestenaoExportLocalBuilder` only. The lower level
  functions of `lib/src/build_data.dart` (`buildDatabaseFromFirestore`,
  `databaseFromFirestore`, `festenaoExportDatabase`,
  `festenaoImportDatabase`) are not exported: the export and import of a
  folder are `FestenaoExportLocalBuilder().exportLocal(db:, directory:)` and
  `importLocal(directory:)`.
* `buildData(assetsFolder:, serviceAccount:, rootPath:, clean:)` is what a
  `tool/build_data.dart` calls: it imports the existing export from
  `assetsFolder`, syncs it down from the firestore subtree at `rootPath` with
  the service account, and exports it again. `clean: true` deletes the json
  files first (not the attachments) to force a full sync.
* The export is two files in `assetsFolder`: `festenao_export.jsonl` (the
  sembast export lines, the sync record store removed) and
  `festenao_export_meta.json` (`sourceVersion`, `lastTimestamp`,
  `lastChangeId` — what makes the next run incremental), plus an `img/`
  sub directory for the attachments.
* Internally (not exported), `buildData` syncs a `SyncedDb` down through
  `FestenaoSourceFirestore` and `FestenaoDbSourceSync` with the service
  account, then writes the export. Nothing is exported when the database
  has no sync meta: the meta is what an import needs to continue.
* `FestenaoExportLocalBuilder` does the same steps as a class:
  `exportLocal(db:, directory:)`, `importLocal(directory:)` (a `SyncedDb`
  in memory), and the whole builds `storageBuildData` (from an export in
  Storage) and `firestoreBuildData` (from Firestore), both downloading the
  images too.
* Images: `buildData` downloads them from the `<projectId>.appspot.com`
  bucket (the default bucket of the projects created before October 2024);
  a newer project (`<projectId>.firebasestorage.app`) gets a `fail for
  <image>` line per image and no `img/` file: use
  `FestenaoExportLocalBuilder`, which reads the bucket of its
  `FirebaseStorageContext`. An image already in `img/` is never downloaded
  again (delete it to refresh a changed image).
* Legacy layer: the export works on the sembast `SyncedDb`
  (tekaly_sembast_synced), the format the festenao apps read from their
  assets. New local database code goes on sdb (festenao_common
  `FestenaoSdb`, tekaly_sdb_synced), not on this layer.
* This runs with a service account, so it belongs in a support package's
  `tool/`, never in an app: the app only reads the produced assets.
* Commit the export with the app when the content ships with it; the
  incremental meta makes the next run cheap, so a stale export is a stale
  app, not a faster build.

## Examples

### The assets build of an app

```dart
// tool/build_data.dart, run from the support package.
import 'package:festenao_support/festenao_synced_data.dart';
import 'package:my_app_common/constant.dart';
import 'package:my_app_common/service_account.dart';

var _assetsFolder = '../my_app/assets/data';

Future<void> main() async {
  await appBuildData();
}

/// Syncs the festenao data down and exports it to the app assets.
///
/// [clean] forces a full sync (the json files are deleted first).
Future<void> appBuildData({bool clean = false}) async {
  await buildData(
    clean: clean,
    assetsFolder: _assetsFolder,
    serviceAccount: myAppServiceAccount,
    rootPath: myAppProjectRootPath,
  );
}
```

### Reading an export back

```dart
import 'dart:io';

import 'package:festenao_support/festenao_synced_data.dart';

/// The exported database, as the app sees it.
Future<void> printExport(String assetsFolder) async {
  var db = await FestenaoExportLocalBuilder().importLocal(
    directory: Directory(assetsFolder),
  );
  var sdb = await db.database;
  print('version ${sdb.version}');
  await db.close();
}
```

## Common mistakes

* Deleting `festenao_export_meta.json` alone: the next sync then starts from
  scratch silently, or worse, exports a database whose meta no longer matches
  its content. `clean: true` removes both.
* Exporting a database that was never synced: without sync meta nothing is
  written, and the empty assets folder looks like a successful build.
* Running it from an app package: the service account belongs to the support
  tool, and an app that syncs at build time has no offline content.
* A `rootPath` that is not the project root of the app: the sync succeeds and
  the export is empty.

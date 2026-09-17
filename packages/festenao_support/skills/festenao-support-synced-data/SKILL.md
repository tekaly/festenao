---
name: festenao-support-synced-data
description: >-
  Use when exporting festenao synced data to an app's assets, or reading it
  back, with festenao_support: buildData (the incremental assets build),
  buildDatabaseFromFirestore / databaseFromFirestore (FestenaoSourceFirestore
  and FestenaoDbSourceSync down to a SyncedDb), festenaoExportDatabase /
  festenaoImportDatabase (the festenao_export.jsonl and
  festenao_export_meta.json pair) and FestenaoExportLocalBuilder.
---

# festenao_support synced data

An app that ships its content reads it from its assets, not from firestore: a
support tool syncs the festenao database down with a service account, exports
it as jsonl next to the images, and the app opens that export as its local
database. `buildData` is the whole round trip, incremental — it imports the
previous export, syncs what changed since, and writes it back.

## Guidelines

* Import `package:festenao_support/festenao_synced_data.dart` (`buildData`,
  `FestenaoExportLocalBuilder`). The lower level functions
  (`buildDatabaseFromFirestore`, `databaseFromFirestore`,
  `festenaoExportDatabase`, `festenaoImportDatabase`) come with it.
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
* `databaseFromFirestore(db:, rootPath:, firestore:/serviceAccount:)` syncs a
  `SyncedDb` down through `FestenaoSourceFirestore` and
  `FestenaoDbSourceSync` and prints the sync stat; pass a `firestore` when
  the context already exists, a `serviceAccount` map otherwise (exactly one
  of them). `buildDatabaseFromFirestore` does the same on a fresh in-memory
  database.
* `festenaoImportDatabase(directory:/assetsFolder:)` returns the `SyncedDb`
  of an export, `festenaoExportDatabase(db:, directory:/assetsFolder:)`
  writes one. Nothing is exported when the database has no sync meta: the
  meta is what an import needs to continue.
* `FestenaoExportLocalBuilder` is the same export/import pair as a class, for
  a builder that also handles the local attachments.
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

### A one-off export of a firestore subtree

```dart
import 'package:festenao_support/festenao_synced_data.dart';

Future<void> exportProject({
  required Map serviceAccount,
  required String rootPath,
  required String outDirectory,
}) async {
  var db = await buildDatabaseFromFirestore(
    rootPath: rootPath,
    serviceAccount: serviceAccount,
  );
  await festenaoExportDatabase(db: db, assetsFolder: outDirectory);
  await db.close();
}
```

### Reading an export back

```dart
import 'package:festenao_support/festenao_synced_data.dart';

/// The exported database, as the app sees it.
Future<void> printExport(String assetsFolder) async {
  var db = await festenaoImportDatabase(assetsFolder: assetsFolder);
  var sdb = await db.database;
  print('version ${sdb.version}');
  await db.close();
}
```

## Common mistakes

* Deleting `festenao_export_meta.json` alone: the next sync then starts from
  scratch silently, or worse, exports a database whose meta no longer matches
  its content. `clean: true` removes both.
* Passing neither `firestore` nor `serviceAccount` to
  `databaseFromFirestore`: it throws an `ArgumentError`, one of them is
  required.
* Exporting a database that was never synced: without sync meta nothing is
  written, and the empty assets folder looks like a successful build.
* Running it from an app package: the service account belongs to the support
  tool, and an app that syncs at build time has no offline content.
* A `rootPath` that is not the project root of the app: the sync succeeds and
  the export is empty.

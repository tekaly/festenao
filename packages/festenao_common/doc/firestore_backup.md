**Location:** `festenao_common` (`lib/data/firestore_backup.dart`,
implementation in `lib/src/backup/`), the UI in `festenao_common_flutter`
(`lib/src/firestore_backup_flutter.dart`). The export comparison helpers are in
`tekaly_synced_db_common`.

**Goal**

Back a firestore tree up — a collection, a document, a whole instance — and
export a synced source in the tekaly format.

---

### 1. The backup is flat

Every document is held under its **full path**:

```json
{
  "festenao_firestore_backup": 1,
  "root": "config",
  "takenAt": "2026-09-22T10:00:00.000Z",
  "documents": {
    "config/main": {"name": "main", "when": {"$timestamp": "2024-01-02T…"}},
    "config/main/items/one": {"index": 1}
  }
}
```

The shape of the tree is in the keys rather than in the nesting, which is what
makes a backup easy to read, to diff and to restore: a document goes back where
its path says, whatever is above it.

```dart
var backup = FirestoreBackup(firestore: firestore);
var data = await backup.readCollection('config');   // and everything below it
await explorer.writeAsString('config.json', backup.toJsonText(data));

var read = backup.fromJsonText(await explorer.readAsString('config.json'));
await backup.restore(read);
```

`readDocument` and `readAll` take the other two starting points, `maxDepth` and
`limit` cap a big one. The values keep their types — a timestamp, a blob, a geo
point, a reference — being encoded through the same registry
[the object editor](object_editor.md) uses.

Walking the sub collections needs `FirestoreService.supportsListCollections`;
`FirestoreBackup.walksSubCollections` says up front whether it will.

---

### 2. To sdb instead

One store per collection, one record per document, keyed by its id:

```dart
var database = await explorer.createSdbDatabase(
  'config.db',
  schema: firestoreBackupSdbSchema(data),
  onCreate: (db) => writeFirestoreBackupToSdb(data, db,
      typeRegistry: backup.typeRegistry),
);
```

The result is an ordinary sdb database, so
[the file system explorer](file_system_explorer.md) browses it like any other,
and `readFirestoreBackupFromSdb` reads it back.

---

### 3. The synced source export

A synced source — the change log a `SyncedDbSynchronizer` reads — is not a tree
and does not export as one. It exports in the **tekaly format**, the same one a
local synced database exports itself in:

```dart
var exportInfo = await firestoreSyncedSourceExportInMemory(firestore);
var files = syncedSourceExportFiles(exportInfo);
await explorer.writeAsString('export.jsonl', files.jsonl);
await explorer.writeAsString('export.meta.json', files.meta);
```

`firestoreSyncedSourceImportFromMemory` puts it back.

**The two sides match**, which is the point of the format and what
`tekaly_synced_db_common` now has helpers to check:

```dart
var local = await syncedSdb.exportInMemory();
var remote = await source.exportInMemory();
expect(local.findContentDifference(remote), isNull);
```

`SyncedDbExportInfoCompareExt` compares what is meant to match — the records,
by store and key — and leaves out the meta line, since the change id, the
timestamp and the source version are each side's own bookkeeping.
`findContentDifference` names the first store, key or value that disagrees
rather than printing two exports; `matchesContent`, `recordsByStore`,
`contentLines`, `storeNames` and `recordCount` are the rest of it.

A synchronized sdb database and its firestore source, both in memory, are
checked against each other in
`tekaly/packages/sdb_synced_test/test/synced_sdb_export_firestore_test.dart`,
and the festenao side in `test/backup/synced_source_backup_test.dart`.

---

### 4. From the explorer

`FirestoreExplorerScreen` offers the backup once it is given somewhere to write
it: a button in the app bar for the whole tree, one per collection row for that
collection. The dialog picks the format — json, sdb, synced source export — and
the name.

```dart
await goToFirestoreExplorerScreen(
  context,
  firestore: firestore,
  backupExplorer: FileSystemExplorer(fileSystem: fileSystemIo, rootPath: '.'),
);
```

The [admin build](admin_explorer.md) wires it to the whole file system, so it
can back up without being told where first.

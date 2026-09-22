/// Backing up a firestore tree, and exporting a synced source.
///
/// [FirestoreBackup] reads a collection, a document or a whole instance out
/// whole — the sub collections included — and puts it back. The backup is flat:
/// every document is held under its full path, which is what makes it easy to
/// read, to diff and to restore.
///
/// It goes to json, or to an sdb database with a store per collection, see
/// [firestoreBackupSdbSchema] and [writeFirestoreBackupToSdb]. The values keep
/// their types either way, being encoded through the same registry the object
/// editor uses.
///
/// A synced source — the change log a `SyncedDbSynchronizer` reads — exports
/// in the tekaly format instead, see
/// [firestoreSyncedSourceExportInMemory]; that export matches the one a local
/// synced database produces, which
/// `SyncedDbExportInfoCompareExt.findContentDifference` checks.
library;

export 'package:tekaly_synced_db_common/synced_db_common.dart'
    show
        SyncedDbExportInfo,
        SyncedDbExportInfoCompareExt,
        SyncedDbExportInfoExt,
        SyncedDbExportMeta,
        SyncedSourceExportExt,
        SyncedSourceImportExt,
        syncedDbExportHeaderLine;

export '../src/backup/firestore_backup.dart'
    show
        FirestoreBackup,
        FirestoreBackupData,
        firestoreBackupFormatKey,
        firestoreBackupFormatVersion,
        firestoreBackupSdbSchema,
        firestoreBackupSdbStoreName,
        readFirestoreBackupFromSdb,
        writeFirestoreBackupToSdb;
export '../src/backup/synced_source_backup.dart'
    show
        SyncedSourceExportFiles,
        firestoreSyncedSourceExportInMemory,
        firestoreSyncedSourceImportFromMemory,
        syncedSourceExportFiles;

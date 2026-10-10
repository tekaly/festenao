import 'package:festenao_common/data/src/festenao/sync/sync_source_options.dart';
import 'package:festenao_common/data/src/festenao_sdb.dart';
import 'package:festenao_common/data/src/festenao_synced_sdb.dart';
import 'package:festenao_common/src/data/projects_sdb/user_projects_sdb.dart';
import 'package:fs_shim/fs.dart';
import 'package:path/path.dart';
import 'package:tekaly_sdb_synced/synced_sdb.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:tekartik_firebase_storage/storage.dart';

/// Opens an [AutoSynchronizedFirestoreSyncedSdb] for a given project at
/// `app/<app>/project/<projectUid>/data/<dataId>`.
///
/// Reused by every project-scoped content database (blog, festenao content, …).
Future<FestenaoSyncedSdb> openProjectFestenaoSyncedSdb({
  FileSystem? fs,
  FileSystem? rootFs,
  required String app,
  required SdbFactory sdbFactory,

  required SdbUserProject project,
  required String dataId,
  required Firestore firestore,
  required FirebaseStorage firebaseStorage,
  required SdbOpenDatabaseOptions openOptions,
}) async {
  var projectUid = project.uid.v!;
  var dbName = '${dataId}_${app}_${projectUid}_synced.db';
  var fileSystem = fs;
  var rootDocPath = 'app/$app/project/$projectUid/data/$dataId';
  var syncSourceOption = FestenaoSyncSourceOptions(
    firebaseProjectId: projectUid,
    firestoreRoot: rootDocPath,
    storageRoot: rootDocPath,
    storageBucket: firebaseStorage.app.options.storageBucket!,
  );
  fileSystem ??= rootFs!.sandbox(path: rootFs.path.join(projectUid, dataId));
  var factory = sdbFactory.sandbox(path: join(projectUid, dataId));
  var festenaoSdb = FestenaoSdb(
    sdbFactory: factory,
    dbName: dbName,
    fs: fileSystem,
    syncedSdbOptions: SyncedSdbOptions(openDatabaseOptions: openOptions),
  );
  await festenaoSdb.ready;
  return FestenaoSyncedSdb(
    db: festenaoSdb,
    sourceOptions: syncSourceOption,
    firebaseStorage: firebaseStorage,
    firestore: firestore,
  );
}

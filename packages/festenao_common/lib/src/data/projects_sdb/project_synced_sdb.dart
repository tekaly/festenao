import 'package:festenao_common/data/src/festenao/sync/sync_source_options.dart';
import 'package:festenao_common/data/src/festenao_sdb.dart';
import 'package:festenao_common/data/src/festenao_synced_sdb.dart';
import 'package:festenao_common/src/data/projects_sdb/user_projects_sdb.dart';
import 'package:fs_shim/fs.dart';
import 'package:path/path.dart';
import 'package:tekaly_sdb_synced/synced_sdb.dart';
import 'package:tekaly_sdb_synced/synced_source.dart'
    show SyncedSourcePartition;
import 'package:tekaly_sdb_synced_media/synced_media.dart'
    show SyncedMediaCacheOptions;
import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:tekartik_firebase_storage/storage.dart';

/// Opens an [AutoSynchronizedFirestoreSyncedSdb] for a given project at
/// `app/<app>/project/<projectUid>/data/<dataId>`.
///
/// Reused by every project-scoped content database (blog, festenao content, …).
///
/// The local database is `<dataId>_<app>_<projectUid>_synced.db` in the
/// `<projectUid>/<dataId>` sandbox of [sdbFactory]. Before 2026-11 the name
/// was ignored (the database was `synced_sdb.db`): such a database is moved
/// on open.
///
/// With a filtered [partition] (a user id), only the records of its value are
/// synchronized down, in a local database of their own (the cursor of a
/// partition is not valid for another one, `_<field>_<value>` added to the
/// name): see [SyncedSourcePartition].
///
/// The medias are in [storageBucket], the default bucket of [firebaseStorage]
/// when null. Without either (a server app with no bucket configured, that
/// only reads the records), the records sync and the medias do not.
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

  /// Media contents kept locally, all by default.
  SyncedMediaCacheOptions mediaCacheOptions =
      const SyncedMediaCacheOptions.all(),

  /// The bucket of the medias, the default one of [firebaseStorage] when
  /// null.
  String? storageBucket,

  /// The partition of the records, if any (every writer of [dataId] names
  /// its field).
  SyncedSourcePartition? partition,
}) async {
  var projectUid = project.uid.v!;
  var filtered = partition?.isFiltered ?? false;
  var dbName = filtered
      ? '${dataId}_${app}_${projectUid}_${partition!.field}_${partition.value}'
            '_synced.db'
      : '${dataId}_${app}_${projectUid}_synced.db';
  var fileSystem = fs;
  var rootDocPath = 'app/$app/project/$projectUid/data/$dataId';
  var syncSourceOption = FestenaoSyncSourceOptions(
    firebaseProjectId: projectUid,
    firestoreRoot: rootDocPath,
    storageRoot: rootDocPath,
    storageBucket:
        storageBucket ?? firebaseStorage.app.options.storageBucket ?? '',
    partition: partition,
  );
  fileSystem ??= rootFs!.sandbox(path: rootFs.path.join(projectUid, dataId));
  var factory = sdbFactory.sandbox(path: join(projectUid, dataId));
  var festenaoSdb = FestenaoSdb(
    sdbFactory: factory,
    dbName: dbName,
    // The database of the whole data id only: a partition never takes it.
    previousDbName: filtered ? null : SyncedSdb.nameDefault,
    fs: fileSystem,
    syncedSdbOptions: SyncedSdbOptions(openDatabaseOptions: openOptions),
  );
  await festenaoSdb.ready;
  return FestenaoSyncedSdb(
    db: festenaoSdb,
    sourceOptions: syncSourceOption,
    firebaseStorage: firebaseStorage,
    firestore: firestore,
    mediaCacheOptions: mediaCacheOptions,
  );
}

import 'dart:convert';

import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:festenao_common/data/festenao_media_sdb_synchronizer.dart';
import 'package:festenao_common/data/festenao_media_source.dart';
import 'package:festenao_common/data/festenao_media_source_firebase.dart';
import 'package:festenao_common/festenao_sdb.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:tekartik_firebase_storage_fs/storage_fs.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_storage.dart';

void main() {
  late FestenaoMediaSdb db;
  late FestenaoMediaSource source;
  late SdbDatabase sdbDb;
  late FirebaseStorage firebaseStorage;
  late FestenaoMediaSdbSynchronizer synchronizer;

  setUp(() async {
    sdbDb = await newSdbFactoryMemory().openDatabase(
      'test',
      options: SdbOpenDatabaseOptions(
        schema: SdbDatabaseSchema(stores: sdbMediaSchemaStores),
      ),
    );
    db = FestenaoMediaSdb(fs: newFileSystemMemory(), database: sdbDb);
    var firebaseLocal = FirebaseLocal();
    var app = firebaseLocal.initializeApp(
      options: FirebaseAppOptions(
        projectId: 'test',
        storageBucket: 'test_bucket',
      ),
    );

    firebaseStorage = newStorageServiceMemory().storage(app);
    source = FestenaoMediaSourceFirebase(
      storageContext: FirebaseStorageContext(
        storage: firebaseStorage, // Not used in this test
        rootDirectory: 'test_media',
      ),
    );
    synchronizer = FestenaoMediaSdbSynchronizer(db: db, source: source);
  });
  tearDown(() async {
    await sdbDb.close();
    await firebaseStorage.app.delete();
  });
  test('nothing', () async {
    expect(await synchronizer.sync(), SyncedSyncStat());
  });
  test('add/delete', () async {
    var id = await db.addMediaFile(
      file: FestenaoMediaFile.from(filename: 'test.txt'),
      bytes: utf8.encode('test_content'),
    );
    expect(await synchronizer.sync(), SyncedSyncStat(remoteCreatedCount: 1));
    expect(await synchronizer.sync(), SyncedSyncStat());
    await db.deleteMediaFile(id);
    expect(await db.getMediaFileRecord(id), isNotNull);
    expect(await synchronizer.sync(), SyncedSyncStat(remoteDeletedCount: 1));
    expect(await db.getMediaFileRecord(id), isNull);
  });
  test('add then mark as not downloaded', () async {
    var id = await db.addMediaFile(
      file: FestenaoMediaFile.from(filename: 'test.txt'),
      bytes: utf8.encode('test_content'),
    );
    expect(await synchronizer.sync(), SyncedSyncStat(remoteCreatedCount: 1));
    await db.markLocalNotPresent(id);
    expect(await synchronizer.sync(), SyncedSyncStat(localCreatedCount: 1));
  });
  test('add then delete remotely', () async {
    var id = await db.addMediaFile(
      file: FestenaoMediaFile.from(filename: 'test.txt'),
      bytes: utf8.encode('test_content'),
    );
    expect(await synchronizer.sync(), SyncedSyncStat(remoteCreatedCount: 1));
    await db.markRemoteDeleted(id);
    expect(await db.getMediaFileRecord(id), isNotNull);
    expect(await synchronizer.sync(), SyncedSyncStat(localDeletedCount: 1));
    expect(await db.getMediaFileRecord(id), isNull);
  });
}

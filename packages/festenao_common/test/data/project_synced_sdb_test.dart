import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/festenao_synced_sdb.dart'
    show FestenaoSyncedSdb;
import 'package:festenao_common/data/src/import.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:path/path.dart';
import 'package:tekaly_sdb_synced/synced_sdb.dart';
import 'package:tekaly_sdb_synced/synced_source.dart'
    show SyncedSourcePartition;
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

/// A record of a user.
class _DbUserItem extends ScvStringRecordBase {
  final userId = CvField<String>('userId');

  @override
  List<CvField> get fields => [userId];
}

final _userItemStore = scvStringStoreFactory.store<_DbUserItem>('user_item');

final _openOptions = SdbOpenDatabaseOptions(
  version: 1,
  schema: SdbDatabaseSchema(
    stores: [
      _userItemStore.schema(),
      ...sdbMediaSchemaStores,
      ...syncedSdbMetaSchema.stores,
    ],
  ),
);

Future<FirebaseContext> _initFirebase() async {
  var services = await initFirebaseServicesMemory();
  services.appOptions = FirebaseAppOptions(
    projectId: 'partition',
    storageBucket: 'bucket-partition.appspot.com',
  );
  return await services.init();
}

Future<void> _close(FestenaoSyncedSdb synced) async {
  await synced.synchronizeMedias();
  synced.dispose();
}

void main() {
  cvAddConstructor(_DbUserItem.new);

  test('a database of the previous name is moved', () async {
    var firebaseContext = await _initFirebase();
    var sdbFactory = newSdbFactoryMemory();
    // Opened before 2026-11: the default name in the project sandbox, a
    // local change not synchronized yet.
    var previous = SyncedSdb(
      name: SyncedSdb.nameDefault,
      databaseFactory: sdbFactory.sandbox(path: 'p1/presence'),
      options: SyncedSdbOptions(openDatabaseOptions: _openOptions),
    );
    await (_userItemStore.record('a').cv()..userId.v = 'u1').put(
      await previous.database,
    );
    await previous.close();

    var synced = await openProjectFestenaoSyncedSdb(
      fs: newFileSystemMemory(),
      app: 'test',
      sdbFactory: sdbFactory,
      project: SdbUserProject()..uid.v = 'p1',
      dataId: 'presence',
      firestore: firebaseContext.firestore,
      firebaseStorage: firebaseContext.storage,
      openOptions: _openOptions,
    );
    var db = await synced.db.syncedSdb.database;
    // In the project sandbox (the platform separator).
    expect(db.name, join('p1', 'presence', 'presence_test_p1_synced.db'));
    expect((await _userItemStore.record('a').get(db))?.userId.v, 'u1');
    // Still to push: the move kept the change pending.
    await synced.synchronize();
    expect(
      (await firebaseContext.firestore
              .doc('app/test/project/p1/data/presence/data/user_item|a')
              .get())
          .exists,
      isTrue,
    );
    await _close(synced);
  });

  test('a user synchronizes only its records', () async {
    var firebaseContext = await _initFirebase();
    // One factory: the admin and the user databases must not collide.
    var sdbFactory = newSdbFactoryMemory();

    Future<FestenaoSyncedSdb> open({String? userId}) =>
        openProjectFestenaoSyncedSdb(
          fs: newFileSystemMemory(),
          app: 'test',
          sdbFactory: sdbFactory,
          project: SdbUserProject()..uid.v = 'p1',
          dataId: 'presence',
          firestore: firebaseContext.firestore,
          firebaseStorage: firebaseContext.storage,
          openOptions: _openOptions,
          partition: SyncedSourcePartition(field: 'userId', value: userId),
        );
    Future<List<String>> idsOf(FestenaoSyncedSdb synced) async => [
      for (var record in await _userItemStore.findRecords(
        await synced.db.syncedSdb.database,
      ))
        record.id,
    ];
    var admin = await open();
    var adminDb = await admin.db.syncedSdb.database;
    for (var (id, userId) in [('a', 'u1'), ('b', 'u2'), ('c', null)]) {
      await (_userItemStore.record(id).cv()..userId.v = userId).put(adminDb);
    }
    await admin.synchronize();

    var user1 = await open(userId: 'u1');
    await user1.synchronize();
    expect(await idsOf(user1), ['a']);

    await _userItemStore.record('a').delete(adminDb);
    await admin.synchronize();
    await user1.synchronize();
    expect(await idsOf(user1), isEmpty);
    expect(await idsOf(admin), ['b', 'c']);

    await _close(user1);
    await _close(admin);
  });
}

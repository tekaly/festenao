import 'package:festenao_common/data/festenao_db.dart';
import 'package:sembast/utils/sembast_import_export.dart';
import 'package:test/test.dart';

void main() {
  group('festenao_db', () {
    late FestenaoDb festenaoDb;
    setUp(() async {
      festenaoDb = FestenaoDb.newInMemory();
    });
    tearDown(() async {
      await festenaoDb.close();
    });
    test('stores', () async {
      expect(festenaoDb.dbSyncMetaStoreRef.name, 'faoM');
      expect(festenaoDb.dbSyncRecordStoreRef.name, 'faoR');
      expect(festenaoDb.syncedStoreNames, [
        'artist',
        'event',
        'image',
        'info',
        'meta',
      ]);
    });
    test('add/delete record', () async {
      var db = await festenaoDb.database;
      var key =
          (await dbArtistStoreRef.add(
            db,
            DbArtist()..name.v = 'test',
          )).rawRef.key;
      expect(await festenaoDb.getSyncRecords(), [
        DbSyncRecord()
          ..store.v = dbArtistStoreRef.name
          ..key.v = key
          ..dirty.v = true,
      ]);
      await dbArtistStoreRef.record(key).delete(db);
      expect(await festenaoDb.getSyncRecords(), [
        DbSyncRecord()
          ..store.v = dbArtistStoreRef.name
          ..key.v = key
          ..dirty.v = true
          ..deleted.v = true,
      ]);
    });
    test('putRecord', () async {
      var record = dbArtistStoreRef.record('test');
      var database = await festenaoDb.database;
      await (record.cv()..name.v = 'test').put(database);
      expect(await festenaoDb.getSyncRecords(), [
        DbSyncRecord()
          ..store.v = dbArtistStoreRef.name
          ..key.v = 'test'
          ..dirty.v = true,
      ]);

      /// Manualle delete the sync record so that it gets re-created
      await dbSyncRecordStoreRef.record(1).delete(database);

      await (record.cv()..name.v = 'test2').put(database);
      expect(await festenaoDb.getSyncRecords(), [
        DbSyncRecord()
          ..store.v = dbArtistStoreRef.name
          ..key.v = 'test'
          ..dirty.v = true,
      ]);
    });
    test('delete record', () async {
      var record = dbArtistStoreRef.record('test_delete');
      var database = await festenaoDb.database;
      await record.rawRef.delete(database);
      expect(await festenaoDb.getSyncRecords(), isEmpty);
      festenaoDb.trackChangesDisabled = true;
      await record.rawRef.add(database, {'1': '2'});
      festenaoDb.trackChangesDisabled = false;
      expect(await festenaoDb.getSyncRecords(), isEmpty);
      await record.rawRef.delete(database);
      expect(await festenaoDb.getSyncRecords(), [
        DbSyncRecord()
          ..store.v = dbArtistStoreRef.name
          ..key.v = 'test_delete'
          ..dirty.v = true
          ..deleted.v = true,
      ]);
    });
    test('ext', () async {
      var record = dbArtistStoreRef.record('test_ext');
      var database = await festenaoDb.database;
      var artist = record.cv()..name.v = 'test';
      await artist.put(database);
      expect((await record.get(database)), artist);
      expect((await dbArtistStoreRef.query().getRecords(database)), [artist]);

      var map = (await record.get(database))!;
      expect(map, artist);
      map.field('name')!.v = 'another';
      map.field('name2')?.v = 'another2';
      expect(map.toMap(), {'name': 'another'});
    });
    test('export', () async {
      var record = dbArtistStoreRef.record('export');
      var database = await festenaoDb.database;
      var artist = record.cv()..name.v = 'test';
      await artist.put(database);
      expect((await record.get(database)), artist);
      expect(await exportDatabaseLines(database), [
        {'sembast_export': 1, 'version': 2},
        {'store': 'artist'},
        [
          'export',
          {'name': 'test'},
        ],
        {'store': 'faoR'},
        [
          1,
          {'store': 'artist', 'key': 'export', 'dirty': true},
        ],
      ]);
    });
  });
}

import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/src/festenao/model/source_record.dart';
import 'package:festenao_common/data/src/festenao/sync/festenao_db_source_sync.dart';
import 'package:festenao_common/data/src/festenao/sync/festenao_source.dart';
import 'package:festenao_common/data/src/festenao/sync/festenao_source_firestore.dart';
import 'package:sembast/timestamp.dart';
import 'package:tekaly_sembast_synced/synced_db_internals.dart';
import 'package:test/test.dart';

import 'festenao_source_firestore_test.dart';

void main() {
  group('festenao_db_source_sync_firestore_test', () {
    late FestenaoSourceFirestore source;
    late FestenaoDb festenaoDb;
    late FestenaoDbSourceSync sync;
    setUp(() async {
      festenaoDb = FestenaoDb.newInMemory();
      source = newInMemoryFestenaroSource();
      sync = FestenaoDbSourceSync(db: festenaoDb, source: source);
    });
    test('syncNone', () async {
      var stat = await sync.sync();
      expect(stat, FaoSyncStat());
    });
    test('syncOneToRemote', () async {
      expect(await festenaoDb.getSyncRecords(), isEmpty);
      var db = await festenaoDb.database;
      await (dbArtistStoreRef.record('a1').cv()..name.v = 'test1').put(db);
      var syncRecords = await festenaoDb.getSyncRecords();
      expect(syncRecords.map((r) => r.toMap()), [
        {'store': 'artist', 'key': 'a1', 'dirty': true}
      ]);
      var stat = await sync.syncUp();
      syncRecords = await festenaoDb.getSyncRecords();
      var syncRecord = syncRecords.first;
      expect(syncRecord.syncId.v, isNotNull);
      expect(syncRecord.syncChangeId.v, isNotNull);
      expect(syncRecord.syncTimestamp.v, isNotNull);
      expect(syncRecords.map((r) => r.toMap()), [
        {
          'store': 'artist',
          'key': 'a1',
          'dirty': false,
          'deleted': false,
          'syncTimestamp': syncRecord.syncTimestamp.v,
          'syncId': syncRecord.syncId.v,
          'syncChangeId': 1,
        }
      ]);
      expect(stat, FaoSyncStat(remoteUpdatedCount: 1));
      var sourceRecord = (await source
          .getSourceRecord(FestenaoDataSourceRef(store: 'artist', key: 'a1')))!;
      expect(
          sourceRecord,
          FaoSourceRecord()
            ..syncId.v = sourceRecord.syncId.v
            ..syncTimestamp.v = sourceRecord.syncTimestamp.v
            ..syncChangeId.v = 1
            ..record.v = (FaoSourceRecordData()
              ..store.v = dbArtistStoreRef.name
              ..key.v = 'a1'
              ..deleted.v = false
              ..value.v = {'name': 'test1'}));
      var sourceMeta = (await source.getMetaInfo())!;
      expect(sourceMeta.toMap(), {'lastChangeId': 1});
      // Sync again
      stat = await sync.syncUp(fullSync: true);

      sourceMeta = (await source.getMetaInfo())!;
      expect(sourceMeta.toMap(), {'lastChangeId': 1});
      expect(stat, FaoSyncStat());
    });
    test('syncOneUntrackedToRemote', () async {
      expect(await festenaoDb.getSyncRecords(), isEmpty);
      var db = await festenaoDb.database;
      await (dbArtistStoreRef.record('a1').cv()..name.v = 'test1').put(db);
      var syncRecords = await festenaoDb.getSyncRecords();
      expect(syncRecords, isNotEmpty);
      await syncRecords.delete(db);
      expect(await festenaoDb.getSyncRecords(), isEmpty);

      var stat = await sync.syncUp();
      syncRecords = await festenaoDb.getSyncRecords();
      if (syncRecords.isNotEmpty) {
        var syncRecord = syncRecords.first;
        expect(syncRecord.syncId.v, isNotNull);
        expect(syncRecord.syncChangeId.v, isNotNull);
        expect(syncRecord.syncTimestamp.v, isNotNull);
        expect(syncRecords.map((r) => r.toMap()), [
          {
            'store': 'artist',
            'key': 'a1',
            'dirty': false,
            'deleted': false,
            'syncTimestamp': syncRecord.syncTimestamp.v,
            'syncId': syncRecord.syncId.v,
            'syncChangeId': 1,
          }
        ]);
        expect(stat, FaoSyncStat(remoteUpdatedCount: 1));
        var sourceRecord = (await source.getSourceRecord(
            FestenaoDataSourceRef(store: 'artist', key: 'a1')))!;
        expect(
            sourceRecord,
            FaoSourceRecord()
              ..syncId.v = sourceRecord.syncId.v
              ..syncTimestamp.v = sourceRecord.syncTimestamp.v
              ..syncChangeId.v = 1
              ..record.v = (FaoSourceRecordData()
                ..store.v = dbArtistStoreRef.name
                ..key.v = 'a1'
                ..deleted.v = false
                ..value.v = {'name': 'test1'}));
        var sourceMeta = (await source.getMetaInfo())!;
        expect(sourceMeta.toMap(), {'lastChangeId': 1});
      }
      // Sync again
      stat = await sync.syncUp();
      expect(stat, FaoSyncStat());
      if (syncRecords.isNotEmpty) {
        var sourceMeta = (await source.getMetaInfo())!;
        expect(sourceMeta.toMap(), {'lastChangeId': 1});
      }
    });

    test('syncOneImageToRemote', () async {
      var db = await festenaoDb.database;
      expect(await festenaoDb.getSyncRecords(), isEmpty);
      var storeName = 'image';

      await (dbImageStoreRef.record('a1').cv()..name.v = 'test1').put(db);
      var syncRecords = await festenaoDb.getSyncRecords();
      expect(syncRecords.map((r) => r.toMap()), [
        {'store': 'image', 'key': 'a1', 'dirty': true}
      ]);
      var stat = await sync.syncUp();
      syncRecords = await festenaoDb.getSyncRecords();
      var syncRecord = syncRecords.first;
      expect(syncRecord.syncId.v, isNotNull);
      expect(syncRecord.syncChangeId.v, isNotNull);
      expect(syncRecord.syncTimestamp.v, isNotNull);
      expect(syncRecords.map((r) => r.toMap()), [
        {
          'store': storeName,
          'key': 'a1',
          'dirty': false,
          'deleted': false,
          'syncTimestamp': syncRecord.syncTimestamp.v,
          'syncId': syncRecord.syncId.v,
          'syncChangeId': 1,
        }
      ]);
      expect(stat, FaoSyncStat(remoteUpdatedCount: 1));
      var sourceRecord = (await source.getSourceRecord(
          FestenaoDataSourceRef(store: storeName, key: 'a1')))!;
      expect(
          sourceRecord,
          FaoSourceRecord()
            ..syncId.v = sourceRecord.syncId.v
            ..syncTimestamp.v = sourceRecord.syncTimestamp.v
            ..syncChangeId.v = 1
            ..record.v = (FaoSourceRecordData()
              ..store.v = storeName
              ..key.v = 'a1'
              ..deleted.v = false
              ..value.v = {'name': 'test1'}));
      var sourceMeta = (await source.getMetaInfo())!;
      expect(sourceMeta.toMap(), {'lastChangeId': 1});
      // Sync again
      stat = await sync.syncUp();

      sourceMeta = (await source.getMetaInfo())!;
      expect(sourceMeta.toMap(), {'lastChangeId': 1});
      expect(stat, FaoSyncStat());
    });

    test('syncOneFromRemote', () async {
      var sourceRecord = (await source.putSourceRecord(FaoSourceRecord()
        //..syncId.v = sourceRecord.syncId.v
        // ..syncTimestamp.v = sourceRecord.syncTimestamp.v
        ..record.v = (FaoSourceRecordData()
          ..store.v = dbArtistStoreRef.name
          ..key.v = 'a1'
          ..value.v = {'name': 'test1'})))!;
      expect(sourceRecord.syncId.v, isNotNull);
      expect(sourceRecord.syncTimestamp.v, isNotNull);

      var sourceMeta = (await source.getMetaInfo())!;
      expect(sourceMeta.toMap(), {'lastChangeId': 1});

      expect(await festenaoDb.getSyncMetaInfo(), null);

      /// Full sync
      var stat = await sync.syncDown();
      expect(stat, FaoSyncStat(localUpdatedCount: 1));

      var metaInfo = (await festenaoDb.getSyncMetaInfo())!;
      expect(metaInfo.toMap(),
          {'lastChangeId': 1, 'lastTimestamp': metaInfo.lastTimestamp.v});

      /// again
      stat = await sync.syncDown();
      expect(stat, FaoSyncStat());
    });

    test('syncOneImageFromRemote', () async {
      var sourceRecord = (await source.putSourceRecord(FaoSourceRecord()
        //..syncId.v = sourceRecord.syncId.v
        // ..syncTimestamp.v = sourceRecord.syncTimestamp.v
        ..record.v = (FaoSourceRecordData()
          ..store.v = dbImageStoreRef.name
          ..key.v = 'a1'
          ..value.v = {'name': 'test1'})))!;
      expect(sourceRecord.syncId.v, isNotNull);
      expect(sourceRecord.syncTimestamp.v, isNotNull);

      var sourceMeta = (await source.getMetaInfo())!;
      expect(sourceMeta.toMap(), {'lastChangeId': 1});

      expect(await festenaoDb.getSyncMetaInfo(), null);

      /// Full sync
      var stat = await sync.syncDown();
      expect(stat, FaoSyncStat(localUpdatedCount: 1));

      expect((await dbImageStoreRef.find(await festenaoDb.database)),
          [dbImageStoreRef.record('a1').cv()..name.v = 'test1']);
      var metaInfo = (await festenaoDb.getSyncMetaInfo())!;
      expect(metaInfo.toMap(),
          {'lastChangeId': 1, 'lastTimestamp': metaInfo.lastTimestamp.v});

      /// again
      stat = await sync.syncDown();
      expect(stat, FaoSyncStat());
    });

    test('syncUpdateToRemote', () async {
      var db = await festenaoDb.database;
      await (dbArtistStoreRef.record('a1').cv()..name.v = 'test1').put(db);
      var stat = await sync.syncUp();
      expect(stat, FaoSyncStat(remoteUpdatedCount: 1));
      await (dbArtistStoreRef.record('a1').cv()..name.v = 'test2').put(db);
      stat = await sync.syncUp();
      expect(stat, FaoSyncStat(remoteUpdatedCount: 1));
      stat = await sync.syncUp();
      expect(stat, FaoSyncStat());
    });

    test('syncUpdateFromRemote', () async {
      await source.putSourceRecord(FaoSourceRecord()
        //..syncId.v = sourceRecord.syncId.v
        // ..syncTimestamp.v = sourceRecord.syncTimestamp.v
        ..record.v = (FaoSourceRecordData()
          ..store.v = dbArtistStoreRef.name
          ..key.v = 'a1'
          ..value.v = {'name': 'test1'}));

      /// Full sync
      var stat = await sync.syncDown();
      expect(stat, FaoSyncStat(localUpdatedCount: 1));

      /// update
      await source.putSourceRecord(FaoSourceRecord()
        //..syncId.v = sourceRecord.syncId.v
        // ..syncTimestamp.v = sourceRecord.syncTimestamp.v
        ..record.v = (FaoSourceRecordData()
          ..store.v = dbArtistStoreRef.name
          ..key.v = 'a1'
          ..value.v = {'name': 'test2'}));
      stat = await sync.syncDown();
      expect(stat, FaoSyncStat(localUpdatedCount: 1));
    });

    test('newVersionSyncUpdateFromRemote', () async {
      //debugFaoSync = true;
      await source.putMetaInfo(CvMetaInfoRecord()
        ..version.v = 1
        ..lastChangeId.v = 1
        ..minIncrementalChangeId.v = 0);
      await source.putRawRecord(FaoSourceRecord()
        ..syncId.v = '1'
        ..syncChangeId.v = 1
        ..syncTimestamp.v = Timestamp(1, 0)
        ..record.v = (FaoSourceRecordData()
          ..store.v = dbArtistStoreRef.name
          ..key.v = 'a1'
          ..value.v = {'name': 'test1'}));

      var stat = await sync.syncDown();
      expect(stat, FaoSyncStat(localUpdatedCount: 1));

      // We just change the version and the data
      await source.putMetaInfo(CvMetaInfoRecord()
        ..version.v = 2
        ..lastChangeId.v = 1
        ..minIncrementalChangeId.v = 0);
      await source.putRawRecord(FaoSourceRecord()
        ..syncId.v = '1'
        ..syncChangeId.v = 1
        ..syncTimestamp.v = Timestamp(1, 0)
        ..record.v = (FaoSourceRecordData()
          ..store.v = dbArtistStoreRef.name
          ..key.v = 'a1'
          ..value.v = {'name': 'test2'}));
      stat = await sync.syncDown();
      expect(stat, FaoSyncStat(localUpdatedCount: 1));
    });

    test('syncOneToRemoteThenAnotherOne', () async {
      // debugFaoSync = devWarning(true);
      var db = await festenaoDb.database;
      await (dbArtistStoreRef.record('a2').cv()).put(db);
      var stat = await sync.sync();
      expect(stat, FaoSyncStat(remoteUpdatedCount: 1));
      await (dbArtistStoreRef.record('a1').cv()).put(db);
      stat = await sync.sync();
      expect(stat, FaoSyncStat(remoteUpdatedCount: 1));
    });
  });
}

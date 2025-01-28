import 'package:festenao_common/data/src/festenao/model/source_meta_info.dart';
import 'package:festenao_common/data/src/festenao/model/source_record.dart';
import 'package:festenao_common/data/src/festenao/sync/festenao_source.dart';
import 'package:festenao_common/data/src/festenao/sync/festenao_source_firestore.dart';
import 'package:tekartik_firebase_firestore/firestore.dart' as fb;
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:test/test.dart';

var firebase = FirebaseLocal();

FestenaoSourceFirestore newInMemoryFestenaoSource() {
  fb.Firestore firestore;
  FestenaoSourceFirestore source;
  var app = newFirebaseAppLocal();
  firestore = newFirestoreServiceMemory().firestore(app);
  source = FestenaoSourceFirestore(firestore: firestore, rootPath: null);
  return source;
}

void main() {
  group('festenao_source_firestore_test', () {
    late FestenaoSourceFirestore source;
    setUp(() {
      source = newInMemoryFestenaoSource();
    });
    test('putRecord', () async {
      var record = (await source.putSourceRecord(FaoSourceRecord()
        ..record.v = (FaoSourceRecordData()
          ..store.v = 'test'
          ..key.v = '1')))!;
      expect(record.toMap(), {
        'syncId': record.syncId.v,
        'syncTimestamp': record.syncTimestamp.v,
        'syncChangeId': 1,
        'record': {'store': 'test', 'key': '1', 'deleted': false}
      });
      var syncId = record.syncId.v;
      expect(syncId, isNotNull);
      expect(record.syncTimestamp.v, isNotNull);
      expect(record.recordStore, 'test');
      expect(record.syncChangeId.v, 1);
      record = (await source.putSourceRecord(FaoSourceRecord()
        ..record.v = (FaoSourceRecordData()
          ..store.v = 'test'
          ..key.v = '1')
        ..syncId.v = syncId))!;
      expect(record.toMap(), {
        'syncId': record.syncId.v,
        'syncTimestamp': record.syncTimestamp.v,
        'syncChangeId': 2,
        'record': {'store': 'test', 'key': '1', 'deleted': false}
      });
      expect(record.syncId.v, syncId);
      expect(record.syncChangeId.v, 2);
      // Changing!
      record = (await source.putSourceRecord(FaoSourceRecord()
        ..record.v = (FaoSourceRecordData()
          ..store.v = 'test2'
          ..key.v = '2')
        ..syncId.v = syncId))!;
      expect(record.syncChangeId.v, 3);
      expect(record.syncId.v, isNot(syncId));
      expect(record.syncTimestamp.v, isNotNull);
      expect(record.recordStore, 'test2');
      expect(record.recordKey, '2');
      expect(record.toMap(), {
        'syncId': record.syncId.v,
        'syncTimestamp': record.syncTimestamp.v,
        'syncChangeId': 3,
        'record': {'store': 'test2', 'key': '2', 'deleted': false}
      });
    });
    test('getRecord', () async {
      var syncId = '1234';
      var ref = FestenaoDataSourceRef(store: 'test', key: '1', syncId: syncId);

      var record = await source.getSourceRecord(ref);
      expect(record, isNull);
      record = await source.putSourceRecord(FaoSourceRecord()
        ..record.v = (FaoSourceRecordData()
          ..store.v = 'test'
          ..key.v = '1')
        ..syncId.v = syncId);
      var newSyncId = record!.syncId.v;
      record = (await source.getSourceRecord(ref))!;
      expect(record.syncId.v, newSyncId);
      expect(newSyncId, isNot(syncId));
      // Without syncId
      record = (await source
          .getSourceRecord(FestenaoDataSourceRef(store: 'test', key: '1')))!;
      expect(record.syncId.v, newSyncId);
      // Wrong syncId
      record = (await source
          .getSourceRecord(FestenaoDataSourceRef(store: 'test', key: '1')))!;
      expect(record.syncId.v, newSyncId);
      // Wrong key (fail)
      record = await source.getSourceRecord(
          FestenaoDataSourceRef(store: 'test', key: '2', syncId: newSyncId));
      expect(record, isNull);
    });
    test('getSourceRecordList', () async {
      var list = (await source.getSourceRecordList()).list;
      expect(list, isEmpty);
      var record = await source.putSourceRecord(FaoSourceRecord()
        ..record.v = (FaoSourceRecordData()
          ..store.v = 'test'
          ..key.v = '1'
          ..value.v = {'name': 'test1'}));
      list = (await source.getSourceRecordList()).list;
      expect(list, hasLength(1));
      expect(list.first.syncId.v, record?.syncId.v);
      var record2 = await source.putSourceRecord(FaoSourceRecord()
        ..record.v = (FaoSourceRecordData()
          ..store.v = 'test'
          ..key.v = '2'
          ..value.v = {'name': 'test2'}));
      list = (await source.getSourceRecordList()).list;
      // print(list);
      expect(
          list.map((e) => e.syncId.v), [record?.syncId.v, record2?.syncId.v]);
      //list = await source.getSourceRecordList(limit: 1);
      //expect(list.map((e) => e.syncId.v), [record?.syncId.v]);
      /*
      expect(newSyncId, isNot(syncId));
      // Without syncId
      record = (await source
          .getSourceRecord(FestenaoDataSourceRef(store: 'test', key: '1')))!;
      expect(record.syncId.v, newSyncId);
      // Wrong syncId
      record = (await source
          .getSourceRecord(FestenaoDataSourceRef(store: 'test', key: '1')))!;
      expect(record.syncId.v, newSyncId);
      // Wrong key (fail)
      record = await source.getSourceRecord(
          FestenaoDataSourceRef(store: 'test', key: '2', syncId: newSyncId));
      expect(record, isNull);

       */
    });
    test('metaInfo', () async {
      var info = await source.getMetaInfo();
      expect(info, isNull);
      info = await source
          .putMetaInfo(CvMetaInfoRecord()..minIncrementalChangeId.v = 2);
      expect(info!.minIncrementalChangeId.v!, 2);
      info = (await source
          .putMetaInfo(CvMetaInfoRecord()..minIncrementalChangeId.v = 3))!;
      expect(info.minIncrementalChangeId.v, 3);
      try {
        await source
            .putMetaInfo(CvMetaInfoRecord()..minIncrementalChangeId.v = 1);
        fail('should fail');
      } on StateError catch (_) {
        // print(e);
      }
    });
  });
}

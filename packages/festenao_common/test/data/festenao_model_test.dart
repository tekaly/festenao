import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/src/festenao/model/source_record.dart';
import 'package:festenao_common/data/src/model/db_models.dart';
import 'package:sembast/timestamp.dart';
import 'package:tekaly_sembast_synced/synced_db_internals.dart';
import 'package:test/test.dart';

void main() {
  group('festenao_model', () {
    setUpAll(() {
      initFestenaoDbBuilders();
    });
    group('db', () {
      test('DbSyncRecord', () {
        var record = DbSyncRecord()
          ..store.v = 'store1'
          ..key.v = 'key1'
          ..deleted.v = true
          ..syncChangeId.v = 1
          ..syncId.v = '2'
          ..syncTimestamp.v = Timestamp(3, 0);
        expect(record.dataRecordRef.key, 'key1');
        expect(record.dataRecordRef.store.name, 'store1');
        expect(record.toMap(), {
          'store': 'store1',
          'key': 'key1',
          'deleted': true,
          'syncId': '2',
          'syncTimestamp': Timestamp(3, 0),
          'syncChangeId': 1,
        });
      });
      test('DbSyncMetaInfo', () {
        var record = DbSyncMetaInfo()
          ..source.v = 's1'
          ..sourceId.v = 's2'
          ..lastChangeId.v = 1
          ..lastTimestamp.v = Timestamp(3, 0);
        expect(record.toMap(), {
          'source': 's1',
          'sourceId': 's2',
          'lastChangeId': 1,
          'lastTimestamp': Timestamp(3, 0),
        });
      });
    });
    test('source', () async {
      var sourceRecord = FaoSourceRecord()
        ..record.v = (FaoSourceRecordData()
          ..store.v = 'test'
          ..deleted.v = true
          ..value.v = {'test': 1}
          ..key.v = '1')
        ..syncId.v = '12'
        ..syncChangeId.v = 3
        ..syncTimestamp.v = Timestamp(1, 0);

      expect(sourceRecord.toMap(), {
        'syncId': '12',
        'syncTimestamp': Timestamp(1, 0),
        'syncChangeId': 3,
        'record': {
          'store': 'test',
          'key': '1',
          'value': {'test': 1},
          'deleted': true,
        },
      });
      expect(
        (FaoSourceRecord()..fromMap(sourceRecord.toMap())).toMap(),
        sourceRecord.toMap(),
      );
    });
    test('source metainfo', () async {
      var record = CvMetaInfoRecord()
        ..lastChangeId.v = 1
        ..minIncrementalChangeId.v = 2;

      expect(record.toMap(), {'minIncrementalChangeId': 2, 'lastChangeId': 1});
      expect(
        (CvMetaInfoRecord()..fromMap(record.toMap())).toMap(),
        record.toMap(),
      );
    });
    test('meta', () async {
      var record = dbMetaGeneralRecordRef.cv()
        ..fillModel(cvSembastFillOptions1);
      expect(record.toMap(), {
        'name': 'text_1',
        'description': 'text_2',
        'tags': ['text_3'],
      });
    });
  });
}

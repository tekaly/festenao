import 'package:festenao_common/data/firestore_backup.dart';
import 'package:tekaly_sdb_synced/sdb_scv.dart';
import 'package:tekaly_sdb_synced/synced_sdb_firestore.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:test/test.dart';

/// An entity of the synced database.
class _Entity extends ScvStringRecordBase {
  final name = CvField<String>('name');
  final counter = CvField<int>('counter');

  @override
  List<CvField> get fields => [name, counter];
}

final _entityStore = scvStringStoreFactory.store<_Entity>('entity');

final _schema = SdbDatabaseSchema(
  stores: [_entityStore.schema(), ...syncedSdbMetaSchema.stores],
);

final _options = SyncedSdbOptions(
  openDatabaseOptions: SdbOpenDatabaseOptions(version: 1, schema: _schema),
);

/// A synced sdb database and the firestore source it syncs with, both in
/// memory, holding two entities.
Future<(SyncedSdb, Firestore, SyncedSdbSynchronizer)> _setup() async {
  // ignore: deprecated_member_use
  var firestore = newFirestoreMemory();
  var source = SyncedSourceFirestore(firestore: firestore, rootPath: null);
  var syncedSdb = SyncedSdb.newInMemory(options: _options);
  var db = await syncedSdb.database;
  await (_entityStore.record('a1').cv()
        ..name.v = 'one'
        ..counter.v = 1)
      .put(db);
  await (_entityStore.record('a2').cv()
        ..name.v = 'two'
        ..counter.v = 2)
      .put(db);
  var synchronizer = SyncedSdbSynchronizer(db: syncedSdb, source: source);
  await synchronizer.sync();
  return (syncedSdb, firestore, synchronizer);
}

void main() {
  cvAddConstructor(_Entity.new);

  group('the synced source export', () {
    test('matches what the local synced database exports', () async {
      var (syncedSdb, firestore, synchronizer) = await _setup();
      try {
        var sourceExport = await firestoreSyncedSourceExportInMemory(firestore);
        var localExport = await syncedSdb.exportInMemory();

        // The whole point: the source holds what the database holds.
        expect(localExport.findContentDifference(sourceExport), isNull);
        expect(localExport.recordsByStore, sourceExport.recordsByStore);
        expect(sourceExport.storeNames, ['entity']);
        expect(sourceExport.recordCount, 2);
        expect(sourceExport.contentLines.first, syncedDbExportHeaderLine);
      } finally {
        await synchronizer.close();
        await syncedSdb.close();
      }
    });

    test('writes as a jsonl document and its meta', () async {
      var (syncedSdb, firestore, synchronizer) = await _setup();
      try {
        var exportInfo = await firestoreSyncedSourceExportInMemory(firestore);
        var files = syncedSourceExportFiles(exportInfo);

        expect(files.lineCount, exportInfo.data.length);
        var lines = files.jsonl.trim().split('\n');
        expect(lines.length, files.lineCount);
        expect(lines.first, contains('tekaly_export'));
        expect(lines, contains('{"store":"entity"}'));
        expect(files.meta, contains('lastChangeId'));
      } finally {
        await synchronizer.close();
        await syncedSdb.close();
      }
    });

    test('goes back into another source', () async {
      var (syncedSdb, firestore, synchronizer) = await _setup();
      try {
        var exportInfo = await firestoreSyncedSourceExportInMemory(firestore);

        // ignore: deprecated_member_use
        var otherFirestore = newFirestoreMemory();
        await firestoreSyncedSourceImportFromMemory(
          otherFirestore,
          exportInfo: exportInfo,
        );

        var reExport = await firestoreSyncedSourceExportInMemory(
          otherFirestore,
        );
        expect(reExport.findContentDifference(exportInfo), isNull);

        // And a fresh database syncs from it with the same content.
        var otherSdb = SyncedSdb.newInMemory(options: _options);
        var otherSynchronizer = SyncedSdbSynchronizer(
          db: otherSdb,
          source: SyncedSourceFirestore(
            firestore: otherFirestore,
            rootPath: null,
          ),
        );
        await otherSynchronizer.sync();
        var otherDb = await otherSdb.database;
        expect((await _entityStore.record('a1').get(otherDb))!.name.v, 'one');
        await otherSynchronizer.close();
        await otherSdb.close();
      } finally {
        await synchronizer.close();
        await syncedSdb.close();
      }
    });

    test('says what differs when the two sides disagree', () async {
      var (syncedSdb, firestore, synchronizer) = await _setup();
      try {
        var sourceExport = await firestoreSyncedSourceExportInMemory(firestore);
        // A change that was not synced.
        var db = await syncedSdb.database;
        await (_entityStore.record('a3').cv()..name.v = 'three').put(db);
        var localExport = await syncedSdb.exportInMemory();

        expect(
          localExport.findContentDifference(sourceExport),
          'entity/a3 is missing on the other side',
        );
      } finally {
        await synchronizer.close();
        await syncedSdb.close();
      }
    });
  });
}

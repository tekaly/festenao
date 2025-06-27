import 'package:festenao_common/data/festenao_db.dart';
import 'package:path/path.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/utils/database_utils.dart';
import 'package:sembast/utils/sembast_import_export.dart';
import 'package:tekaly_sembast_synced/synced_db_internals.dart';

import 'import.dart';
import 'model/db_models.dart';

export 'festenao/model/db_sync_meta.dart';
export 'festenao/model/db_sync_record.dart';

final _syncStores = [
  dbArtistStoreRef,
  dbEventStoreRef,
  dbImageStoreRef,
  dbInfoStoreRef,
  dbMetaStoreRef,
];
var festenaoExport = 'festenao_export.jsonl';
var festenaoExportMeta = 'festenao_export_meta.json';
var festenaoImgSubDir = 'img';
var festenaoDbName = 'festenao.db';

/// Default for flutter app
var assetsRootDataPath = url.join('assets', 'data');
var assetsDataExportMetaPath = url.join(assetsRootDataPath, festenaoExportMeta);
var assetsDataExportPath = url.join(assetsRootDataPath, festenaoExport);

var festenaoDbSystemStoreNames = [
  dbSyncRecordStoreRef.name,
  dbSyncMetaStoreRef.name,
];

/// Must be json encodable
class FestenaoExportMeta extends CvModelBase {
  final lastChangeId = CvField<int>('lastChangeId');
  final lastTimestamp = CvField<String>('lastTimestamp');
  final sourceVersion = CvField<int>('sourceVersion');

  @override
  List<CvField> get fields => [lastChangeId, lastTimestamp, sourceVersion];
}

class FestenaoDb extends SyncedDbBase {
  bool _test = false;
  var name = nameDefault;
  static String nameDefault = 'festenao.db';

  static DatabaseFactory get inMemoryDatabaseFactory =>
      newDatabaseFactoryMemory();

  //static DatabaseFactory get inMemoryDatabaseFactory => SqfliteLogget newDatabaseFactoryMemory();
  @visibleForTesting
  FestenaoDb.newInMemory() : this._(inMemoryDatabaseFactory, true);

  static Future<FestenaoDb> fromExport(Map export) async {
    var factory = newDatabaseFactoryMemory();
    var db = await importDatabase(export, factory, nameDefault);
    await db.close();
    return FestenaoDb._(factory, false);
  }

  FestenaoDb._(DatabaseFactory databaseFactory, this._test, {String? name}) {
    this.databaseFactory = databaseFactory;
    syncedStoreNames = _syncStores.map((e) => e.name).toList();
    initFestenaoDbBuilders();

    if (name != null) {
      this.name = name;
    }
  }

  FestenaoDb(DatabaseFactory databaseFactory, {String? name})
    : this._(databaseFactory, false, name: name);

  Future<void> dbClear(Database db) async {
    await db.transaction((txn) async {
      await (txnDbClear(db, txn));
    });
  }

  Future<void> txnDbClear(Database db, Transaction txn) async {
    for (var name in getNonEmptyStoreNames(db)) {
      await StoreRef(name).drop(txn);
    }
  }

  @override
  final dbSyncMetaStoreRef = cvStringStoreFactory.store<DbSyncMetaInfo>('faoM');
  @override
  final dbSyncRecordStoreRef = cvIntStoreFactory.store<DbSyncRecord>('faoR');

  @override
  String toString() {
    return name; // _database?.path ?? '<none>';
  }

  /// Export
  Future<FestenaoExportInfo> export() async {
    var syncMeta = (await getSyncMetaInfo())!;
    var sdb = await database;
    var map = await exportDatabase(
      sdb,
      storeNames: getNonEmptyStoreNames(sdb).toList()
        ..removeWhere(
          (element) => [dbSyncRecordStoreRef.name].contains(element),
        ),
    );

    var exportMeta = FestenaoExportMeta()
      ..sourceVersion.setValue(syncMeta.sourceVersion.v)
      ..lastTimestamp.setValue(syncMeta.lastTimestamp.v?.toIso8601String())
      ..lastChangeId.setValue(syncMeta.lastChangeId.v);
    return FestenaoExportInfo(metaInfo: exportMeta, data: map);
  }

  @override
  late final rawDatabase = databaseFactory.openDatabase(
    name,
    version: 2,
    onVersionChanged: (db, oldVersion, newVersion) async {
      if (oldVersion > 0 && oldVersion < 2) {
        // Clear db
        await dbClear(db);
      }
      if (!_test) {
        // await (artistStore.record('test').cv()..name.v = 'Test name')
        //    .put(db);
      }
    },
  );
}

class FestenaoExportInfo {
  final FestenaoExportMeta metaInfo;
  final Map<String, Object?> data;

  FestenaoExportInfo({required this.metaInfo, required this.data});
}

extension FestenaoDbExt on RecordRef {}

extension FestenaoDbModelListExt on List<DbRecord> {
  Future<void> delete(DatabaseClient client) async {
    for (var record in this) {
      await record.delete(client);
    }
  }
}

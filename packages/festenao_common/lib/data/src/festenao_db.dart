import 'package:festenao_common/data/festenao_db.dart';
import 'package:path/path.dart' as url;
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/utils/database_utils.dart';
import 'package:sembast/utils/sembast_import_export.dart';
import 'package:tekaly_sembast_synced/synced_db_internals.dart';

import 'import.dart';
import 'model/db_models.dart';

export 'festenao/model/db_sync_meta.dart';
export 'festenao/model/db_sync_record.dart';

/// List of store references used for synchronization.
final _syncStores = [
  dbArtistStoreRef,
  dbEventStoreRef,
  dbImageStoreRef,
  dbInfoStoreRef,
  dbMetaStoreRef,
];

/// Default export file name for Festenao data.
var festenaoExport = 'festenao_export.jsonl';

/// Default export meta file name.
var festenaoExportMeta = 'festenao_export_meta.json';

/// Subdirectory name for images within exports or assets.
var festenaoImgSubDir = 'img';

/// Default database file name.
var festenaoDbName = 'festenao.db';

/// Default assets root path for embedded data.
var assetsRootDataPath = url.join('assets', 'data');

/// Default path to export meta file under assets.
var assetsDataExportMetaPath = url.join(assetsRootDataPath, festenaoExportMeta);

/// Default path to export data file under assets.
var assetsDataExportPath = url.join(assetsRootDataPath, festenaoExport);

/// System store names that belong to the festenao DB system.
var festenaoDbSystemStoreNames = [
  dbSyncRecordStoreRef.name,
  dbSyncMetaStoreRef.name,
];

/// Must be JSON encodable: meta information about an export.
class FestenaoExportMeta extends CvModelBase {
  /// Last synchronized change id.
  final lastChangeId = CvField<int>('lastChangeId');

  /// Last timestamp of the export.
  final lastTimestamp = CvField<String>('lastTimestamp');

  /// Source version number.
  final sourceVersion = CvField<int>('sourceVersion');

  @override
  List<CvField> get fields => [lastChangeId, lastTimestamp, sourceVersion];
}

/// Main Festenao synchronized database wrapper.
class FestenaoDb extends SyncedDbBase {
  bool _test = false;
  var name = nameDefault;
  static String nameDefault = 'festenao.db';

  /// In-memory database factory used for tests.
  static DatabaseFactory get inMemoryDatabaseFactory =>
      newDatabaseFactoryMemory();

  @visibleForTesting
  /// Construct a new in-memory FestenaoDb instance (testing only).
  FestenaoDb.newInMemory() : this._(inMemoryDatabaseFactory, true);

  /// Build a FestenaoDb instance from an exported database [export] map.
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

  /// Construct a FestenaoDb with an on-disk [databaseFactory] and optional [name].
  FestenaoDb(DatabaseFactory databaseFactory, {String? name})
    : this._(databaseFactory, false, name: name);

  /// Clear the database content.
  Future<void> dbClear(Database db) async {
    await db.transaction((txn) async {
      await (txnDbClear(db, txn));
    });
  }

  /// Transactional database clear helper.
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

  /// Export the current database into a [FestenaoExportInfo] with meta and data.
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
        // optional bootstrap for non-test environments
      }
    },
  );
}

/// Export result including meta information and the exported data map.
class FestenaoExportInfo {
  /// Meta information about the export.
  final FestenaoExportMeta metaInfo;

  /// Exported data map keyed by store names.
  final Map<String, Object?> data;

  FestenaoExportInfo({required this.metaInfo, required this.data});
}

extension FestenaoDbExt on RecordRef {}

extension FestenaoDbModelListExt on List<DbRecord> {
  /// Delete all records in this list from the provided [client].
  Future<void> delete(DatabaseClient client) async {
    for (var record in this) {
      await record.delete(client);
    }
  }
}

import 'package:festenao_common/data/festenao_fs.dart';
import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:tekaly_sdb_synced/sdb_scv.dart';
import 'package:tekaly_sdb_synced/synced_sdb.dart';
import 'package:tekartik_common_utils/foundation/constants.dart';

import 'import.dart';

export 'festenao/model/db_sync_meta.dart';
export 'festenao/model/db_sync_record.dart';

/// Sdb options
var festenaoSyncedSdbOptions = SyncedSdbOptions(
  openDatabaseOptions: SdbOpenDatabaseOptions(
    version: 1,
    schema: SdbDatabaseSchema(
      stores: [...sdbMediaSchemaStores, ...syncedSdbMetaSchema.stores],
    ),
  ),
);

/// Main Festenao synchronized database wrapper.
class FestenaoSdb {
  /// Database factory.
  final SdbFactory sdbFactory;

  /// The name of the database.
  final String dbName;

  /// Synced db options
  final SyncedSdbOptions syncedSdbOptions;
  late final SyncedSdb _db;
  Future<void> get ready => _ready;
  late final _ready = () async {
    await _db.ready;
    _mediaDb = FestenaoMediaSdb(fs: fs, database: await _db.database);
  }();
  late FestenaoMediaSdb _mediaDb;

  /// Must be ready
  FestenaoMediaSdb get mediaDb => _mediaDb;

  /// File system
  final FileSystem fs;

  /// Constructor
  FestenaoSdb({
    required this.sdbFactory,
    required this.dbName,
    SyncedSdbOptions? syncedSdbOptions,
    required this.fs,
  }) : syncedSdbOptions = syncedSdbOptions ?? festenaoSyncedSdbOptions {
    _db = SyncedSdb(
      databaseFactory: sdbFactory,
      options: this.syncedSdbOptions,
    );
    _ready.then((_) {
      if (kFlutterDebugMode) {
        // ignore: avoid_print
        print('sdb ready');
      }
    });
  }

  /// Must be ready
  SyncedSdb get syncedSdb => _db;

  /*
  bool _test = false;

  /// The name of the database.
  var name = nameDefault;

  /// Default database file name.
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
    //syncedStoreNames = _syncStores.map((e) => e.name).toList();
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

  /// Constructor for [FestenaoExportInfo].
  FestenaoExportInfo({required this.metaInfo, required this.data});
}

/// extension for RecordRef
extension FestenaoDbRecordExt on RecordRef {}

/// extension for List of DbRecord
extension FestenaoDbModelListExt on List<DbRecord> {
  /// Delete all records in this list from the provided [client].
  Future<void> delete(DatabaseClient client) async {
    for (var record in this) {
      await record.delete(client);
    }
  }
}

/// FestenaoDb options
class FestenaoDbOptions {
  /// Db path
  final String dbPath;

  /// Medias path
  final String mediasPath;

  /// Db options
  FestenaoDbOptions({required this.dbPath, required this.mediasPath});
}*/
}

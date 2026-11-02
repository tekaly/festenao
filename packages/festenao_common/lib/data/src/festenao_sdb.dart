import 'package:festenao_common/data/festenao_fs.dart';
import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:tekaly_sdb_synced/sdb_scv.dart';
import 'package:tekaly_sdb_synced/synced_sdb.dart';
import 'package:tekaly_sdb_synced/synced_sdb_internals.dart'
    show sdbSyncMetaStoreRef, sdbSyncRecordStoreRef;
import 'package:tekartik_common_utils/foundation/constants.dart';

import 'import.dart';

/// Sdb options
var festenaoSyncedSdbOptions = SyncedSdbOptions(
  openDatabaseOptions: SdbOpenDatabaseOptions(
    version: 1,
    schema: SdbDatabaseSchema(
      stores: [...sdbMediaSchemaStores, ...syncedSdbMetaSchema.stores],
    ),
  ),
);

/// Main Festenao synchronized database wrapper using SDB (Structured Database).
///
/// Modern structured local database layer that handles schema definition, open operations,
/// and synchronizes records offline-first with firestore.
///
/// ### Example Usage
///
/// #### Instantiating SDB:
/// ```dart
/// import 'package:tekaly_sdb_synced/sdb_scv.dart';
/// import 'package:fs_shim/fs_shim.dart';
///
/// var festenaoSdb = FestenaoSdb(
///   sdbFactory: mySdbFactory,
///   dbName: 'festenao_sdb.db',
///   fs: myFileSystem,
/// );
///
/// // Wait until SDB initialization is complete:
/// await festenaoSdb.ready;
/// ```
///
/// #### Interacting with Media DB:
/// ```dart
/// var mediaDb = festenaoSdb.mediaDb;
/// // Add media files to SDB-backed local storage
/// String mediaId = await mediaDb.addMediaFile(file: file, bytes: bytes);
/// ```
class FestenaoSdb {
  /// The structured database factory used to open the database.
  final SdbFactory sdbFactory;

  /// The name of the SDB database.
  final String dbName;

  /// The name the database had before, if any: when [dbName] holds nothing
  /// yet (never synchronized, no local change) and this one does, it is
  /// moved to [dbName] on open.
  final String? previousDbName;

  /// Options for SDB database open, validation, and schema version management.
  final SyncedSdbOptions syncedSdbOptions;
  late final SyncedSdb _db;

  /// A future that completes when SDB and [FestenaoMediaSdb] are fully initialized and ready.
  Future<void> get ready => _ready;
  late final _ready = () async {
    await _movePreviousDatabase();
    await _db.ready;
    _mediaDb = FestenaoMediaSdb(fs: fs, database: await _db.database);
  }();
  late FestenaoMediaSdb _mediaDb;

  /// Returns the initialized [FestenaoMediaSdb] instance.
  ///
  /// You must wait for [ready] before accessing this getter.
  FestenaoMediaSdb get mediaDb => _mediaDb;

  /// File system reference used for storing media file blobs.
  final FileSystem fs;

  /// Constructor for creating a [FestenaoSdb] instance.
  FestenaoSdb({
    required this.sdbFactory,
    required this.dbName,
    SyncedSdbOptions? syncedSdbOptions,
    required this.fs,
    this.previousDbName,
  }) : syncedSdbOptions = syncedSdbOptions ?? festenaoSyncedSdbOptions {
    _db = SyncedSdb(
      name: dbName,
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

  /// Returns the underlying [SyncedSdb] client wrapper.
  SyncedSdb get syncedSdb => _db;

  /// True when the database [name] was synchronized or holds local changes
  /// (it is created when missing).
  Future<bool> _isInUse(String name) async {
    var db = await sdbFactory.openDatabase(
      name,
      options: syncedSdbOptions.openDatabaseOptions,
    );
    try {
      return await sdbSyncMetaStoreRef.count(db) > 0 ||
          await sdbSyncRecordStoreRef.count(db) > 0;
    } finally {
      await db.close();
    }
  }

  /// Moves the database [previousDbName] to [dbName] when only the previous
  /// one is in use (sync state and local changes included), then deletes it.
  Future<void> _movePreviousDatabase() async {
    var previousDbName = this.previousDbName;
    if (previousDbName == null || previousDbName == dbName) {
      return;
    }
    if (await _isInUse(dbName)) {
      return;
    }
    if (await _isInUse(previousDbName)) {
      await _copyDatabase(previousDbName, dbName);
    }
    await sdbFactory.deleteDatabase(previousDbName);
  }

  /// Copies every record of the database [from] into [to], both opened with
  /// the schema (`sdbImportDatabase` ignores the path of a sandboxed
  /// factory, it is not used).
  Future<void> _copyDatabase(String from, String to) async {
    var options = syncedSdbOptions.openDatabaseOptions;
    var fromDb = await sdbFactory.openDatabase(from, options: options);
    try {
      var toDb = await sdbFactory.openDatabase(to, options: options);
      try {
        for (var name in fromDb.storeNames) {
          var store = SdbStoreRef<Object, Object>(name);
          var records = await store.findRecords(fromDb);
          if (records.isEmpty) {
            continue;
          }
          await toDb.inStoresTransaction(
            [store],
            SdbTransactionMode.readWrite,
            (txn) async {
              for (var record in records) {
                await record.ref.put(txn, record.value);
              }
            },
          );
        }
      } finally {
        await toDb.close();
      }
    } finally {
      await fromDb.close();
    }
  }

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

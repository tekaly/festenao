import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/src/model/db_models.dart';
import 'package:meta/meta.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/utils/database_utils.dart';

/// Store for favorite flags keyed by item id.
var favoriteStore = cvStringStoreFactory.store<DbFavorite>('favorite');

/// User-scoped local database for Festenao (per-install preferences and favorites).
class FestenaoUserDb {
  /// Database factory used to open the underlying sembast database.
  final DatabaseFactory databaseFactory;

  /// Database file name (default 'festenao_user.db').
  var name = nameDefault;

  /// Default database file name.
  static String nameDefault = 'festenao_user.db';

  @visibleForTesting
  /// Creates an in-memory [FestenaoUserDb] for tests.
  FestenaoUserDb.newInMemory() : this._(newDatabaseFactoryMemory());

  FestenaoUserDb._(this.databaseFactory, {String? name}) {
    initFestenaoUserDbBuilders();

    if (name != null) {
      this.name = name;
    }
  }

  /// Creates a FestenaoUserDb backed by the provided [databaseFactory].
  FestenaoUserDb(DatabaseFactory databaseFactory, {String? name})
    : this._(databaseFactory, name: name);

  Future<Database>? _database;

  /// Clears the database content.
  Future<void> dbClear(Database db) async {
    await db.transaction((txn) async {
      await (txnDbClear(db, txn));
    });
  }

  /// Transactional helper to clear the database.
  Future<void> txnDbClear(Database db, Transaction txn) async {
    for (var name in getNonEmptyStoreNames(db)) {
      await StoreRef(name).drop(txn);
    }
  }

  /// Lazily opened database instance.
  Future<Database> get database => _database ??= () async {
    var db = await databaseFactory.openDatabase(
      name,
      version: 2,
      onVersionChanged: (db, oldVersion, newVersion) async {
        if (oldVersion > 0 && oldVersion < 1) {
          // Clear db on incompatible older versions
          await dbClear(db);
        }
      },
    );
    return db;
  }();
}

import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/src/model/db_models.dart';
import 'package:meta/meta.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/utils/database_utils.dart';

var favoriteStore = cvStringStoreFactory.store<DbFavorite>('favorite');

class FestenaoUserDb {
  final DatabaseFactory databaseFactory;
  var name = nameDefault;
  static String nameDefault = 'festenao_user.db';

  @visibleForTesting
  FestenaoUserDb.newInMemory() : this._(newDatabaseFactoryMemory());

  FestenaoUserDb._(this.databaseFactory, {String? name}) {
    initFestenaoUserDbBuilders();

    if (name != null) {
      this.name = name;
    }
  }

  FestenaoUserDb(DatabaseFactory databaseFactory, {String? name})
    : this._(databaseFactory, name: name);

  Future<Database>? _database;

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

  Future<Database> get database =>
      _database ??= () async {
        var db = await databaseFactory.openDatabase(
          name,
          version: 2,
          onVersionChanged: (db, oldVersion, newVersion) async {
            if (oldVersion > 0 && oldVersion < 1) {
              // Clear db
              await dbClear(db);
            }
          },
        );
        // devPrint('${db.path}');
        return db;
      }();
}

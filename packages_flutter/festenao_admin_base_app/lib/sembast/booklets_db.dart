import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/sembast/sembast.dart';
import 'package:tekartik_app_cv_sembast/app_cv_sembast.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

export 'package:tekartik_app_cv_sembast/app_cv_sembast.dart';

/// Reference to a booklet
class BookletRef {
  /// Local id
  final String? id;

  /// Synced id
  final String? syncedId;

  /// Booklet ref
  BookletRef({this.id, this.syncedId}) {
    assert(id != null || syncedId != null);
  }

  /// True if local
  bool get isLocal => syncedId == null;

  /// True if remote
  bool get isRemote => !isLocal;

  ///
  Future<String?> getBookletId() async {
    if (id != null) {
      return id!;
    }
    var userId = (await globalFirebaseContext.auth.onCurrentUser.first)?.uid;
    if (userId != null) {
      var bookletId = (await globalBookletsDb.getBookletBySyncedId(syncedId!,
              userId: userId))
          ?.id;
      if (bookletId != null) {
        return bookletId;
      } else {
        return null;
      }
    }
    return null;
  }
}

/// Key is the user id
class DbBookletUser extends DbStringRecordBase {
  /// Timestamp when the user is ready
  final readyTimestamp = CvField<DbTimestamp>('readyTimestamp');

  @override
  CvFields get fields => [readyTimestamp];
}

/// Booklet
class DbBooklet extends DbStringRecordBase with TkCmsCvUserAccessMixin {
  /// Name
  final name = CvField<String>('name');

  /// Firestore uid for non local
  final uid = CvField<String>('uid');

  /// User id
  final userId = CvField<String>('userId');

  /// True if local
  bool get isLocal => uid.isNull;

  /// True if remote
  bool get isRemote => !isLocal;

  @override
  CvFields get fields => [name, uid, userId, ...userAccessMixinfields];

  /// Booklet ref
  BookletRef get ref {
    return BookletRef(id: id, syncedId: uid.v);
  }

  /// True if the user has write access
  bool get isWrite => isLocal ? true : TkCmsCvUserAccessCommonExt(this).isWrite;

  /// True if the user has admin access
  bool get isAdmin => isLocal ? true : TkCmsCvUserAccessCommonExt(this).isRead;

  /// True if the user has read access
  bool get isRead => isLocal ? true : TkCmsCvUserAccessCommonExt(this).isRead;
}

/// The model
final dbBookletModel = DbBooklet();

/// Initialize the db builders
void initDbBookletsBuilders() {
  cvAddConstructors([DbBooklet.new, DbBookletUser.new]);
}

/// Booklets db
const bookletsDbName = 'booklets_v1.db';

/// Booklet store
final dbBookletStore = cvStringStoreFactory.store<DbBooklet>('booklet');

/// Booklet user store
final dbBookletUserStore =
    cvStringStoreFactory.store<DbBookletUser>('bookletUser');

/// Booklets db
class BookletsDb {
  /// Database
  late final Database db;

  /// ready state
  late final Future<void> ready = () async {
    db = await globalSembastDatabaseFactory.openDatabase(
      bookletsDbName,
    );
    initDbBookletsBuilders();
  }();

  /// on booklets
  Stream<List<DbBooklet>> onBooklets({required String userId}) async* {
    await ready;
    await dbBookletUserStore
        .record(userId)
        .onRecord(db)
        .firstWhere((user) => user?.readyTimestamp.value != null);
    yield* getBookletsQuery(userId: userId).onRecords(db);
  }

  /// Delete booklet
  Future<void> deleteBooklet(BookletRef bookletRef) async {
    var bookletId = await bookletRef.getBookletId();
    if (bookletId != null) {
      await dbBookletStore.record(bookletId).delete(db);
    }
  }

  /// on local booklets
  Stream<List<DbBooklet>> onLocalBooklets() async* {
    await ready;
    yield* getLocalBookletsQuery().onRecords(db);
  }

  /// on booklet
  Stream<DbBooklet?> onBooklet(String bookletId) async* {
    await ready;
    yield* dbBookletStore.record(bookletId).onRecord(db);
  }

  /// Query
  CvQueryRef<String, DbBooklet> getBookletsQuery({required String userId}) {
    return dbBookletStore.query(
        finder: Finder(
            filter: Filter.or([
      Filter.equals(dbBookletModel.userId.name, userId),
      Filter.isNull(dbBookletModel.uid.name),
    ])));
  }

  /// Get local booklets
  CvQueryRef<String, DbBooklet> getLocalBookletsQuery() {
    return dbBookletStore.query(
        finder: Finder(
      filter: Filter.isNull(dbBookletModel.uid.name),
    ));
  }

  /// Get all remote booklets
  CvQueryRef<String, DbBooklet> getAllRemoteBookletsQuery() {
    return dbBookletStore.query(
        finder: Finder(
      filter: Filter.notNull(dbBookletModel.uid.name),
    ));
  }

  /// Get all remote booklets synced
  Future<List<DbBooklet>> getExistingSyncedBooklets(
      {required String userId}) async {
    await ready;
    return dbBookletStore
        .query(
            finder: Finder(
                filter: Filter.equals(dbBookletModel.userId.name, userId)))
        .getRecords(db);
  }

  /// Get booklet by synced id
  Future<DbBooklet?> getBookletBySyncedId(String uid,
      {required String userId}) async {
    await ready;
    return await db.transaction((txn) {
      return txnGetBookletBySyncedId(txn, uid, userId: userId);
    });
  }

  /// Get booklet by synced id
  Future<DbBooklet?> txnGetBookletBySyncedId(DbTransaction txn, String uid,
      {required String userId}) async {
    return dbBookletStore
        .query(
            finder: Finder(
                filter: Filter.and([
          Filter.equals(dbBookletModel.userId.name, userId),
          Filter.equals(dbBookletModel.uid.name, uid)
        ])))
        .getRecord(txn);
  }

  /// Get booklet by local id
  Future<DbBooklet?> getBookletByLocalId(String bookletId) async {
    await ready;
    return dbBookletStore.record(bookletId).getSync(db);
  }

  /// Get booklet by local id
  Future<DbBooklet?> getBooklet(BookletRef bookletRef) async {
    await ready;
    if (bookletRef.id != null) {
      return getBookletByLocalId(bookletRef.id!);
    } else {
      var userId = (await globalFirebaseContext.auth.onCurrentUser.first)?.uid;
      if (userId != null) {
        return getBookletBySyncedId(bookletRef.syncedId!, userId: userId);
      }
    }
    return null;
  }
}

/// Global booklets db
final globalBookletsDb = BookletsDb();

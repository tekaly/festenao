import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_audi.dart';
import 'package:festenao_common/festenao_firestore.dart';

/// Manages the current [UserProjectsSdb] and allows it to be a per user
/// database.
///
/// When a user is authenticated the database is a per user database
/// synchronized to firestore `app/<app>/user_prv/<userId>/data/projects`,
/// locally sandboxed to the user id. Otherwise a plain local database is used.
///
/// [globalProjectsSdbOrNull] is updated on each switch.
class UserProjectsSdbManager {
  /// Base database factory (never sandboxed, each user database is sandboxed
  /// from it).
  final SdbFactory factory;

  /// Firestore instance.
  final Firestore firestore;

  /// App id.
  final String app;

  /// Base name of the database.
  final String? name;

  final _lock = Lock();
  final _dbSubject = BehaviorSubject<UserProjectsSdb?>();
  var _hasCurrent = false;
  String? _currentUserId;
  UserProjectsSdb? _current;

  /// Manages the current [UserProjectsSdb].
  UserProjectsSdbManager({
    required this.factory,
    required this.firestore,
    required this.app,
    this.name,
  });

  /// Current database (null until [setCurrentUser] is called).
  UserProjectsSdb? get currentDb => _dbSubject.valueOrNull;

  /// Current database stream, updated on each user change.
  ValueStream<UserProjectsSdb?> get onCurrentDb => _dbSubject.stream;

  /// Sets the current user (null when not authenticated) and returns the
  /// database now in use, ready.
  ///
  /// For an authenticated user the database is a synced per user database,
  /// otherwise a plain local database. The previous database is closed.
  /// [globalProjectsSdbOrNull] is updated.
  Future<UserProjectsSdb> setCurrentUser(String? userId) {
    return _lock.synchronized(() async {
      if (_hasCurrent && userId == _currentUserId) {
        return _current!;
      }
      var previous = _current;
      UserProjectsSdb db;
      if (userId == null) {
        db = UserProjectsSdb(factory: factory, name: name);
      } else {
        db = UserProjectsSdb.userSynced(
          factory: factory,
          name: name,
          firestore: firestore,
          app: app,
          userId: userId,
        );
      }
      await db.ready;
      _current = db;
      _currentUserId = userId;
      _hasCurrent = true;
      globalProjectsSdbOrNull = db;
      _dbSubject.add(db);
      if (previous != null) {
        await previous.close();
      }
      return db;
    });
  }

  /// Closes the current database.
  Future<void> close() async {
    await _lock.synchronized(() async {
      var current = _current;
      _current = null;
      _hasCurrent = false;
      _currentUserId = null;
      if (identical(globalProjectsSdbOrNull, current)) {
        globalProjectsSdbOrNull = null;
      }
      if (current != null) {
        await current.close();
      }
    });
    await _dbSubject.close();
  }
}

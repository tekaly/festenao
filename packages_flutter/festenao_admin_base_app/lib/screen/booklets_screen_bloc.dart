import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/sembast/booklets_db.dart';
import 'package:festenao_admin_base_app/sembast/sembast.dart';
import 'package:festenao_admin_base_app/utils/sembast_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:tekartik_common_utils/stream/stream_join.dart';
import 'package:tkcms_common/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

import '../firebase/firebase.dart';

/// Booklets screen bloc state
class BookletsScreenBlocState {
  /// User
  final FirebaseUser? user;

  /// Booklets
  final List<DbBooklet> booklets;

  /// Booklets screen bloc state
  BookletsScreenBlocState({required this.booklets, this.user});
}

/// Booklets screen bloc
class BookletsScreenBloc
    extends AutoDisposeStateBaseBloc<BookletsScreenBlocState> {
  // ignore: cancel_subscriptions
  StreamSubscription? _dbSubscription,
      // ignore: cancel_subscriptions
      _firestoreSubscription,
      // ignore: cancel_subscriptions
      _bookletDetailsSubscription;
  String? _dbUserId;
  bool _gotFirstUser = false;
  late final _lock = Lock(); // globalBookletsBloc.syncLock;
  final _fsLock = Lock();

  /// Booklets screen bloc
  BookletsScreenBloc() {
    audiAddStreamSubscription(
        globalAdminAppFirebaseContext.auth.onCurrentUser.listen((user) {
      _lock.synchronized(() async {
        var userId = user?.uid;
        if (userId != _dbUserId || !_gotFirstUser) {
          _gotFirstUser = true;
          _dbUserId = userId;
          audiDispose(_dbSubscription);
          audiDispose(_firestoreSubscription);
          audiDispose(_bookletDetailsSubscription);

          if (userId == null) {
            _dbSubscription = audiAddStreamSubscription(
                globalBookletsDb.onLocalBooklets().listen((booklets) {
              add(BookletsScreenBlocState(booklets: booklets, user: user));
            }));
          } else {
            _dbSubscription = audiAddStreamSubscription(globalBookletsDb
                .onBooklets(userId: _dbUserId!)
                .listen((booklets) {
              add(BookletsScreenBlocState(booklets: booklets, user: user));
            }));

            /// Build from firestore
            var fsDb = globalNotelioFirestoreDatabase.bookletDb;
            var bookletsDb = globalBookletsDb;
            _firestoreSubscription = audiAddStreamSubscription(fsDb
                .fsUserEntityAccessCollectionRef(userId)
                .onSnapshots(fsDb.firestore)
                .listen((list) async {
              var bookletUids = list.map((e) => e.id).toList();
              var bookletAccessMap = <String, TkCmsFsUserAccess>{};
              for (var item in list) {
                bookletAccessMap[item.id] = item;
              }

              audiDispose(_bookletDetailsSubscription);

              if (bookletUids.isEmpty) {
                await bookletsDb.ready;
                await bookletsDb.db.transaction((txn) async {
                  await dbBookletStore.delete(txn,
                      finder: Finder(
                          filter: Filter.equals(
                              dbBookletModel.userId.name, userId)));
                  await dbBookletUserStore.record(userId).put(txn,
                      DbBookletUser()..readyTimestamp.v = DbTimestamp.now());
                });
                return;
              }
              // Some error might happen (access) so handle it.
              _bookletDetailsSubscription = audiAddStreamSubscription(
                  streamJoinAllOrError(bookletUids
                          .map((id) => (fsDb.fsEntityCollectionRef
                              .doc(id)
                              .onSnapshot(fsDb.firestore)))
                          .toList())
                      .listen((items) {
                _fsLock.synchronized(() async {
                  // var bookletsUser = await dbBookletUserStore.record(userId).get(bookletsDb.db);
                  var dbBooklets = await bookletsDb.getExistingSyncedBooklets(
                      userId: userId);
                  var bookletMap = {
                    for (var booklet in dbBooklets) booklet.uid.v!: booklet
                  };
                  var toDelete = dbBooklets.map((e) => e.id).toSet();
                  var toSet = <DbBooklet>[];
                  for (var item in items) {
                    if (item.error == null) {
                      var fsBooklet = item.value!;
                      var uid = fsBooklet.id;
                      var existing = bookletMap[uid];
                      var userBookletAccess = bookletAccessMap[uid];
                      if (userBookletAccess == null) {
                        // ? this might delete id
                        continue;
                      }
                      if (existing != null) {
                        if (fsBooklet.deleted.v != true) {
                          toDelete.remove(existing.id);
                          var newDbBooklet = DbBooklet()
                            ..fromFirestore(
                                fsBooklet: fsBooklet,
                                bookletAccess: userBookletAccess,
                                userId: userId);
                          if (existing.needUpdate(newDbBooklet)) {
                            existing.copyFrom(newDbBooklet);
                            toSet.add(existing);
                          }
                        }
                      } else {
                        var newDbBooklet = DbBooklet()
                          ..fromFirestore(
                              fsBooklet: fsBooklet,
                              bookletAccess: userBookletAccess,
                              userId: userId);
                        toSet.add(newDbBooklet);
                      }
                    }
                  }

                  await bookletsDb.db.transaction((txn) async {
                    for (var id in toDelete) {
                      await dbBookletStore.record(id).delete(txn);
                    }
                    for (var booklet in toSet) {
                      if (booklet.idOrNull == null) {
                        await dbBookletStore.add(txn, booklet);
                      } else {
                        await dbBookletStore
                            .record(booklet.id)
                            .put(txn, booklet);
                      }
                      await dbBookletStore.record(booklet.id).put(txn, booklet);
                    }
                    await dbBookletUserStore.record(userId).put(txn,
                        DbBookletUser()..readyTimestamp.v = DbTimestamp.now());
                  });
                });
              }, onError: (error) {
                if (kDebugMode) {
                  print('error getting booklet details');
                }
              }));
            }, onError: (error) {
              if (kDebugMode) {
                print(
                    'error listing ${fsDb.fsUserEntityAccessCollectionRef(userId).path}');
              }
            }));
          }
        } else {
          if (!state.hasValue && userId == null) {
            add(BookletsScreenBlocState(booklets: []));
          }
        }
      });
    }));
  }
}

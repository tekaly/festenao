import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tkcms_common/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_common.dart';

/// Apps screen bloc state
class FsAppsScreenBlocState {
  /// User
  final TkCmsFbIdentity? identity;

  /// Apps
  final List<TkCmsFsApp> apps;

  /// Apps screen bloc state
  FsAppsScreenBlocState({required this.apps, required this.identity});
}

/// Apps screen bloc
class FsAppsScreenBloc extends AutoDisposeStateBaseBloc<FsAppsScreenBlocState> {
  // ignore: cancel_subscriptions
  StreamSubscription? _firestoreSubscription;

  TkCmsFbIdentity? _fbIdentity;

  late final _lock = Lock(); // globalAppsBloc.syncLock;
  final _fsLock = Lock();
  final bool selectMode;

  void refresh() {
    assert(_fbIdentity != null);

    /// Build from firestore
    var fsDb = globalFestenaoFirestoreDatabase.appDb;
    var firestore = globalFestenaoFirestoreDatabase.firestore;

    if (firestore.service.supportsTrackChanges &&
        _firestoreSubscription != null) {
      return;
    }
    audiDispose(_firestoreSubscription);

    _firestoreSubscription = audiAddStreamSubscription(
      fsDb.fsEntityCollectionRef.onSnapshotsSupport(fsDb.firestore).listen((
        list,
      ) {
        _fsLock.synchronized(() async {
          add(FsAppsScreenBlocState(apps: list, identity: _fbIdentity));
          // var AppsUser = await dbAppUserStore.record(userId).get(AppsDb.db);
        });
      }),
    );
  }

  /// Apps screen bloc
  FsAppsScreenBloc({this.selectMode = false}) {
    () async {
      audiAddStreamSubscription(
        globalTkCmsFbIdentityBloc.state.listen((state) {
          _lock.synchronized(() async {
            var identity = state.identity;

            if (identity != null && (_fbIdentity != identity)) {
              _fbIdentity = identity;

              refresh();
            } else {
              if (identity == null) {
                _fbIdentity = null;

                add(FsAppsScreenBlocState(apps: [], identity: identity));
              }
            }
          });
        }),
      );
    }();
  }
}

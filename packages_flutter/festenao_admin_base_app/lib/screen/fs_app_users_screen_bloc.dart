import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/festenao_firestore.dart';

import 'package:tkcms_common/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_common.dart';

/// Projects screen bloc state
class FsAppUsersScreenBlocState {
  /// User
  final TkCmsFbIdentity? identity;

  /// Projects
  final List<TkCmsFsUserAccess> userAccessList;

  /// Projects screen bloc state
  FsAppUsersScreenBlocState({required this.userAccessList, this.identity});
}

/// Projects screen bloc
class FsAppUsersScreenBloc
    extends AutoDisposeStateBaseBloc<FsAppUsersScreenBlocState> {
  // ignore: cancel_subscriptions
  StreamSubscription? _firestoreSubscription;

  late final _lock = Lock(); // globalProjectsBloc.syncLock;
  final _fsLock = Lock();
  final bool selectMode;
  final String? appId;
  TkCmsFbIdentity? _fbIdentity;

  String get _appId => appId ?? globalFestenaoFirestoreDatabase.app;
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

    var appId = _appId;
    var coll = fsDb.fsEntityUserAccessCollectionRef(appId);

    _firestoreSubscription = audiAddStreamSubscription(
      coll.onSnapshotsSupport(fsDb.firestore).listen((list) {
        _fsLock.synchronized(() async {
          add(
            FsAppUsersScreenBlocState(
              identity: _fbIdentity,
              userAccessList: list,
            ),
          );
          // var ProjectsUser = await dbProjectUserStore.record(userId).get(ProjectsDb.db);
        });
      }),
    );
  }

  /// Projects screen bloc
  FsAppUsersScreenBloc({this.selectMode = false, this.appId}) {
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
                add(
                  FsAppUsersScreenBlocState(
                    identity: identity,
                    userAccessList: [],
                  ),
                );
              }
            }
          });
        }),
      );
    }();
  }
}

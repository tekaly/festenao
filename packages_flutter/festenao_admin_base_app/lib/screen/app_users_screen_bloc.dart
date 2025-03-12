import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/festenao_firestore.dart';

import 'package:tkcms_common/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_common.dart';

/// Projects screen bloc state
class FsAppUsersScreenBlocState {
  /// User
  final FirebaseUser? user;

  /// Projects
  final List<TkCmsFsUserAccess> projects;

  /// Projects screen bloc state
  FsAppUsersScreenBlocState({required this.projects, this.user});
}

/// Projects screen bloc
class FsAppUsersScreenBloc
    extends AutoDisposeStateBaseBloc<FsAppUsersScreenBlocState> {
  // ignore: cancel_subscriptions
  StreamSubscription? _firestoreSubscription;
  String? _dbUserId;

  late final _lock = Lock(); // globalProjectsBloc.syncLock;
  final _fsLock = Lock();
  final bool selectMode;
  final String? app;

  /// Projects screen bloc
  FsAppUsersScreenBloc({this.selectMode = false, this.app}) {
    () async {
      audiAddStreamSubscription(
        globalTkCmsFbIdentityBloc.state.listen((state) {
          _lock.synchronized(() async {
            var identity = state.identity;

            var userId =
                (identity is TkCmsFbIdentityUser) ? identity.user.uid : null;
            if (identity != null &&
                (userId != _dbUserId || _firestoreSubscription == null)) {
              _dbUserId = userId;

              audiDispose(_firestoreSubscription);

              /// Build from firestore
              var fsDb = globalFestenaoFirestoreDatabase.appDb;
              var app = this.app ?? globalFestenaoFirestoreDatabase.app;
              _firestoreSubscription = audiAddStreamSubscription(
                fsDb
                    .fsEntityUserAccessCollectionRef(app)
                    .onSnapshots(fsDb.firestore)
                    .listen((list) {
                      _fsLock.synchronized(() async {
                        add(FsAppUsersScreenBlocState(projects: list));
                        // var ProjectsUser = await dbProjectUserStore.record(userId).get(ProjectsDb.db);
                      });
                    }),
              );
            } else {
              if (userId == null) {
                _dbUserId = null;
                add(FsAppUsersScreenBlocState(projects: []));
              }
            }
          });
        }),
      );
    }();
  }
}

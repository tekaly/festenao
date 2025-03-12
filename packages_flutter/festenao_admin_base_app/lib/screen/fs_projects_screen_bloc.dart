import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tkcms_admin_app/auth/fb_identity_bloc.dart';
import 'package:tkcms_common/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_common.dart';

/// Projects screen bloc state
class FsProjectsScreenBlocState {
  /// User
  final FirebaseUser? user;

  /// Projects
  final List<FsProject> projects;

  /// Projects screen bloc state
  FsProjectsScreenBlocState({required this.projects, this.user});
}

/// Projects screen bloc
class FsProjectsScreenBloc
    extends AutoDisposeStateBaseBloc<FsProjectsScreenBlocState> {
  // ignore: cancel_subscriptions
  StreamSubscription? _firestoreSubscription;
  String? _dbUserId;

  late final _lock = Lock(); // globalProjectsBloc.syncLock;
  final _fsLock = Lock();
  final bool selectMode;

  /// Projects screen bloc
  FsProjectsScreenBloc({this.selectMode = false}) {
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
              var fsDb = globalFestenaoFirestoreDatabase.projectDb;
              _firestoreSubscription = audiAddStreamSubscription(
                fsDb.fsEntityCollectionRef
                    .onSnapshotsSupport(fsDb.firestore)
                    .listen((list) {
                      _fsLock.synchronized(() async {
                        add(FsProjectsScreenBlocState(projects: list));
                        // var ProjectsUser = await dbProjectUserStore.record(userId).get(ProjectsDb.db);
                      });
                    }),
              );
            } else {
              if (userId == null) {
                _dbUserId = null;
                add(FsProjectsScreenBlocState(projects: []));
              }
            }
          });
        }),
      );
    }();
  }
}

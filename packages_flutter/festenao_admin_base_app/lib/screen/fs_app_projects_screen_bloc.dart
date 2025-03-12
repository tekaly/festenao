import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/festenao_firestore.dart';

import 'package:tkcms_common/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_common.dart';

/// Projects screen bloc state
class FsAppProjectsScreenBlocState {
  /// User
  final TkCmsFbIdentity? identify;

  /// Projects
  final List<FsProject> projects;

  /// Projects screen bloc state
  FsAppProjectsScreenBlocState({required this.projects, this.identify});
}

/// Projects screen bloc
class FsProjectsScreenBloc
    extends AutoDisposeStateBaseBloc<FsAppProjectsScreenBlocState> {
  // ignore: cancel_subscriptions
  StreamSubscription? _firestoreSubscription;
  TkCmsFbIdentity? _fbIdentity;

  late final _lock = Lock(); // globalProjectsBloc.syncLock;
  final _fsLock = Lock();
  final bool selectMode;

  void refresh() {
    assert(_fbIdentity != null);

    /// Build from firestore
    var fsDb = globalFestenaoFirestoreDatabase.projectDb;
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
          add(FsAppProjectsScreenBlocState(projects: list));
          // var ProjectsUser = await dbProjectUserStore.record(userId).get(ProjectsDb.db);
        });
      }),
    );
  }

  /// Projects screen bloc
  FsProjectsScreenBloc({this.selectMode = false}) {
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
                add(FsAppProjectsScreenBlocState(projects: []));
              }
            }
          });
        }),
      );
    }();
  }
}

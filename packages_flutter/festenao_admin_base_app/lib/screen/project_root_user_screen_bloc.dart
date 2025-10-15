import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/screen/project_root_users_screen_bloc.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';

class AdminUserScreenBlocState {
  final String projectId;
  AdminUserScreenBlocState({required this.projectId, required this.user});

  final TkCmsEditedFsUserAccess user;
}

class AdminUserScreenBloc
    extends AutoDisposeStateBaseBloc<AdminUserScreenBlocState> {
  late final String projectId;
  final String userId;
  TkCmsEditedFsUserAccess? user;
  var snapshotSupportController = TrackChangesSupportOptionsController();

  void _checkResult() {
    if (user != null) {
      add(AdminUserScreenBlocState(projectId: projectId, user: user!));
    }
  }

  void refresh() {
    snapshotSupportController.trigger();
  }

  AdminUserScreenBloc({required String projectId, required this.userId}) {
    this.projectId = adminProjectFixProjectId(projectId);
    var fsDb = globalFestenaoFirestoreDatabase.projectDb;
    var userAccessRef = fsDb
        .fsEntityUserAccessRef(this.projectId, userId)
        .cast<TkCmsEditedFsUserAccess>();
    audiAddStreamSubscription(
      userAccessRef
          .onSnapshotSupport(fsDb.firestore, options: snapshotSupportController)
          .listen((snapshot) {
            user = snapshot;
            _checkResult();
          }),
    );
  }
}

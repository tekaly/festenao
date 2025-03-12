import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

class AdminUserScreenBlocState {
  final String projectId;
  AdminUserScreenBlocState({required this.projectId, required this.user});

  final TkCmsFsUserAccess user;
}

class AdminUserScreenBloc
    extends AutoDisposeStateBaseBloc<AdminUserScreenBlocState> {
  final String projectId;
  final String userId;
  TkCmsFsUserAccess? user;

  void trigger() {
    if (user != null) {
      add(AdminUserScreenBlocState(projectId: projectId, user: user!));
    }
  }

  AdminUserScreenBloc({required this.projectId, required this.userId}) {
    var fsDb = globalFestenaoFirestoreDatabase.projectDb;
    var userAccessRef = fsDb.fsEntityUserAccessRef(projectId, userId);
    audiAddStreamSubscription(
      userAccessRef.onSnapshot(fsDb.firestore).listen((snapshot) {
        user = snapshot;
        trigger();
      }),
    );
  }
}

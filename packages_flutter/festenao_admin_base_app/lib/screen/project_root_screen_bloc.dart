import 'package:festenao_admin_base_app/auth/auth_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tekartik_firebase_auth_local/auth_local.dart';

class ProjectRootScreenBlocState {
  final FirebaseUser? user;
  final DbProject? project;

  ProjectRootScreenBlocState({this.project, this.user});
}

class ProjectRootScreenBloc
    extends AutoDisposeStateBaseBloc<ProjectRootScreenBlocState> {
  FestenaoAdminAppProjectContext get projectContext =>
      ByProjectIdAdminAppProjectContext(projectId: projectId);
  final String projectId;

  String get userId => firebaseUser!.uid;
  FirebaseUser? firebaseUser;
  ProjectRootScreenBloc({required this.projectId}) {
    () async {
      var user = ((await globalAuthBloc.state.first).user);
      if (user == null) {
        add(ProjectRootScreenBlocState());
      } else {
        firebaseUser = user;

        audiAddStreamSubscription(globalProjectsDb
            .onProject(projectId, userId: user.uid)
            .listen((event) {
          var project = event;
          add(ProjectRootScreenBlocState(project: project, user: user));
        }));
      }
    }();
  }
}

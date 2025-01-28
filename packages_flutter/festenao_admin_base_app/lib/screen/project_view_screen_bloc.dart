import 'package:festenao_admin_base_app/auth/auth_bloc.dart';
import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tekartik_firebase_auth_local/auth_local.dart';

class ProjectViewScreenBlocState {
  final FirebaseUser? user;
  final DbProject? project;

  ProjectViewScreenBlocState({this.project, this.user});
}

class ProjectViewScreenBloc
    extends AutoDisposeStateBaseBloc<ProjectViewScreenBlocState> {
  final ProjectRef projectRef;

  String get userId => firebaseUser!.uid;
  FirebaseUser? firebaseUser;
  ProjectViewScreenBloc({required this.projectRef}) {
    () async {
      var user = ((await globalAuthBloc.state.first).user);
      if (user == null) {
        add(ProjectViewScreenBlocState());
      } else {
        firebaseUser = user;

        var projectId = projectRef.id ?? await projectRef.getProjectId();
        if (projectId == null) {
          add(ProjectViewScreenBlocState(project: null, user: user));
        } else {
          audiAddStreamSubscription(
              globalProjectsDb.onProject(projectId).listen((event) {
            var project = event;
            add(ProjectViewScreenBlocState(project: project, user: user));
          }));
        }
      }
    }();
  }

  Future<void> deleteProject(DbProject project) async {
    if (project.isLocal) {
      await dbProjectStore.record(project.id).delete(globalProjectsDb.db);
    } else {
      await globalFestenaoFirestoreDatabase.projectDb
          .deleteEntity(project.uid.v!, userId: userId);
    }
  }

  Future<void> leaveProject(DbProject project) async {
    await globalFestenaoFirestoreDatabase.projectDb
        .leaveEntity(project.uid.v!, userId: userId);
  }
}

import 'package:festenao_admin_base_app/auth/auth_bloc.dart';
import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/sembast/projects_db_bloc.dart';
import 'package:festenao_common/sembast/projects_db_synchronizer.dart';
import 'package:tekaly_sembast_synced/synced_db_firestore.dart';
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

  var _syncTriedOnce = false;
  String get userId => firebaseUser!.uid;
  FirebaseUser? firebaseUser;

  /// Explicit db bloc to access the database
  //late   AdminAppProjectContextDbBloc dbBloc = audiAddDisposable(AdminAppProjectContextDbBloc(projectContext: projectContext));

  ProjectRootScreenBloc({required this.projectId}) {
    () async {
      if (globalProjectsDbBloc is SingleProjectDbBloc) {
        add(
          ProjectRootScreenBlocState(
            project: DbProject()
              ..uid.v = ByProjectIdAdminAppProjectContext.mainProjectId,
            user: null,
          ),
        );
        return;
      }

      var user = ((await globalAuthBloc.state.first).user);
      if (user == null) {
        add(ProjectRootScreenBlocState());
      } else {
        firebaseUser = user;

        audiAddStreamSubscription(
          globalProjectsDb.onProject(projectId, userId: user.uid).listen((
            event,
          ) async {
            var project = event;
            add(ProjectRootScreenBlocState(project: project, user: user));
            if (project == null && !_syncTriedOnce) {
              _syncTriedOnce = true;
              var synchronizer = ProjectsDbSynchronizer(
                projectsDb: globalProjectsDb,
                fsProjects: globalFestenaoFirestoreDatabase.projectDb,
              );
              await synchronizer.syncOne(
                projectId: projectId,
                userId: user.uid,
              );
            }
          }),
        );
      }
    }();
  }

  Future<void> sync() async {
    /// Only for single project mode with a predefined synced db
    if (globalProjectsDbBloc is SingleProjectDbBloc) {
      var syncedDb = (globalProjectsDbBloc as SingleProjectDbBloc).syncedDb;

      var synchronizer = SyncedDbSynchronizer(
        db: syncedDb,
        source: SyncedSourceFirestore(
          firestore: globalFestenaoFirestoreDatabase.firestore,
          rootPath: globalFestenaoAppFirebaseContext.firestoreRootPath,
        ),
      );
      await synchronizer.sync();
      //(globalProjectsDbBloc as SingleProjectDbBloc).syncedDb.sync();
    }
  }
}

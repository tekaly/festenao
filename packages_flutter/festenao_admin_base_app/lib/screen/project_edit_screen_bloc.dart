import 'package:festenao_admin_base_app/auth/auth_bloc.dart';
import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:festenao_admin_base_app/utils/sembast_utils.dart';
import 'package:tkcms_common/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_common.dart';

/// Projects screen bloc state
class ProjectEditScreenBlocState {
  /// User
  final FirebaseUser? user;

  /// Projects
  final DbProject? project;

  /// Projects screen bloc state
  ProjectEditScreenBlocState({this.project, this.user});
}

/// Projects screen bloc
class ProjectEditScreenBloc
    extends AutoDisposeStateBaseBloc<ProjectEditScreenBlocState> {
  final DbProject? project; // null for creation

  bool get isCreate => project == null;

  FirebaseUser? firebaseUser;

  /// Projects screen bloc
  ProjectEditScreenBloc({this.project}) {
    () async {
      var user = ((await globalAuthBloc.state.first).user);
      if (user == null) {
        add(ProjectEditScreenBlocState());
      } else {
        firebaseUser = user;
        add(ProjectEditScreenBlocState(project: project, user: user));
      }
    }();
  }

  Future<void> saveProject(DbProject project) async {
    await globalProjectsDb.ready;
    var fsDb = globalFestenaoFirestoreDatabase;
    var firestore = fsDb.firestore;
    if (isCreate) {
      var fsProject = FsProject()..name.setValue(project.name.v);
      var userId = firebaseUser!.uid;
      var projectUid =
          await fsDb.projectDb.createEntity(userId: userId, entity: fsProject);
      var userProjectAccess = await fsDb.projectDb
          .fsUserEntityAccessRef(userId, projectUid)
          .get(firestore);
      var newDbProject = DbProject()
        ..fromFirestore(
            fsProject: fsProject,
            projectAccess: userProjectAccess,
            userId: userId);
      await globalProjectsDb.addProject(newDbProject);
    } else {
      throw UnsupportedError('update not supported yet');
    }
    /*
    if (project.isLocal) {
      throw UnsupportedError('local not supported here');
      //await dbProjectStore.record(projectId).put(globalProjectsDb.db, project);
    } else {
      var fsProjectRef = fsDb.fsProjectCollection.doc(project.uid.v!);
      var fsProject = await fsProjectRef.get(fsDb.firestore);
      if (fsProject.name.v != project.name.v) {
        await fsProjectRef.update(
            fsDb.firestore, FsProject()..name.v = project.name.v);
      }
      // Also save locally for immediate update
      //await dbProjectStore.record(projectId).put(globalProjectsDb.db, project);
    }*/
  }
}

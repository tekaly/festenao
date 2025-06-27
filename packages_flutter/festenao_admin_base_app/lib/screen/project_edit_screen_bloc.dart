import 'package:festenao_admin_base_app/auth/auth_bloc.dart';
import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:festenao_admin_base_app/utils/sembast_utils.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
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

  String get projectId => project!.id;
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
      var projectUid = await fsDb.projectDb.createEntity(
        userId: userId,
        entity: fsProject,
      );
      var userProjectAccess = await fsDb.projectDb
          .fsUserEntityAccessRef(userId, projectUid)
          .get(firestore);
      var newDbProject = DbProject()
        ..fromFirestore(
          fsProject: fsProject,
          projectAccess: userProjectAccess,
          userId: userId,
        );
      await globalProjectsDb.addProject(newDbProject);
    } else {
      await firestore.cvRunTransaction((txn) async {
        var fsProjectRef = fsDb.projectDb.fsEntityRef(project.fsId);

        var fsProject = await txn.refGet(fsProjectRef);
        if (!fsProject.exists) {
          throw UnsupportedError('project not found');
        }
        fsProject.name.setValue(project.name.v);
        txn.refUpdate(fsProjectRef, fsProject);
      });
      await globalProjectsDb.db.transaction((txn) async {
        var dbProject = await dbProjectStore.record(projectId).get(txn);
        if (dbProject == null) {
          throw UnsupportedError('Local project not found');
        }
        dbProject.name.v = project.name.v;
        await dbProjectStore.record(projectId).put(txn, dbProject);
      });
    }
  }
}

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:tkcms_common/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Projects screen bloc state
class ProjectSdbEditScreenBlocState {
  final TkCmsFbIdentity? identity;

  /// User
  FirebaseUser? get user => identity?.user;

  /// Projects
  final SdbUserProject? project;

  /// Projects screen bloc state
  ProjectSdbEditScreenBlocState({this.project, this.identity});
}

/// Projects screen bloc
class ProjectEditScreenBloc
    extends AutoDisposeStateBaseBloc<ProjectSdbEditScreenBlocState> {
  final SdbUserProject? project; // null for creation

  String get projectId => project!.id;
  bool get isCreate => project == null;

  TkCmsFbIdentity? firebaseIdentity;

  /// Projects screen bloc
  ProjectEditScreenBloc({this.project}) {
    () async {
      var identity = firebaseIdentity =
          ((await globalTkCmsFbIdentityBloc.state.first).identity);
      if (identity == null) {
        add(ProjectSdbEditScreenBlocState());
      } else {
        add(
          ProjectSdbEditScreenBlocState(project: project, identity: identity),
        );
      }
    }();
  }

  Future<void> saveProject(SdbUserProject project) async {
    await globalProjectsSdb.ready;
    var fsDb = globalFestenaoFirestoreDatabase;
    var firestore = fsDb.firestore;
    if (isCreate) {
      var fsProject = FsProject()..name.setValue(project.name.v);
      var identity = firebaseIdentity;
      var userId = identity?.userId;

      var projectUid = await fsDb.projectDb.createEntity(
        userId: userId,
        entity: fsProject,
      );
      if (userId == null) {
        var newDbProject = SdbUserProject()
          ..fromFirestore(
            fsProject: fsProject,
            projectId: projectUid,
            projectAccess: TkCmsFsUserAccess.admin(),
            userId: identity!.userLocalId!,
          );
        await globalProjectsSdb.addProject(newDbProject);
      } else {
        var userProjectAccess = await fsDb.projectDb
            .fsUserEntityAccessRef(userId, projectUid)
            .get(firestore);
        var newDbProject = SdbUserProject()
          ..fromFirestore(
            fsProject: fsProject,
            projectId: projectUid,
            projectAccess: userProjectAccess,
            userId: userId,
          );
        await globalProjectsSdb.addProject(newDbProject);
      }
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
      await globalProjectsSdb.db.inStoreTransaction(
        dbProjectStore.rawRef,
        SdbTransactionMode.readWrite,
        (txn) async {
          var dbProject = await dbProjectStore.record(projectId).get(txn);
          if (dbProject == null) {
            throw UnsupportedError('Local project not found');
          }
          dbProject.name.v = project.name.v;
          await dbProjectStore.record(projectId).put(txn, dbProject);
        },
      );
    }
  }
}

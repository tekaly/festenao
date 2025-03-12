import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/screen/fs_app_project_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/fs_app_view_screen_bloc.dart';
import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_common.dart';

/// Projects screen bloc state
class FsAppProjectEditScreenBlocState {
  /// User
  final TkCmsFbIdentity? user;

  /// Projects
  final FsProject? project;

  /// Projects screen bloc state
  FsAppProjectEditScreenBlocState({this.project, this.user});
}

/// Projects screen bloc
class FsAppProjectEditScreenBloc
    extends FsAppBlocRawBase<FsAppProjectEditScreenBlocState> {
  final FsProject? project; // null for creation

  String? get projectId => project?.id;
  bool get isCreate => project == null;

  /// Projects screen bloc
  FsAppProjectEditScreenBloc({this.project, super.appId}) {
    () async {
      add(FsAppProjectEditScreenBlocState(project: project, user: fbIdentity));
    }();
  }

  Future<void> saveProject(FsAppProjectEditData data) async {
    var project = data.project;
    var projectId = data.projectId;
    await globalProjectsDb.ready;
    var ffdb = this.ffdb;
    var projectDb = ffdb.projectDb;
    var firestore = ffdb.firestore;
    if (isCreate) {
      var fsProject = FsProject()..name.setValue(project.name.v);
      await projectDb.createEntity(
        userId: userId,
        entity: fsProject,
        entityId: projectId,
      );
    } else {
      await firestore.cvRunTransaction((txn) async {
        var fsProjectRef = projectDb.fsEntityRef(projectId!);

        var fsProject = await txn.refGet(fsProjectRef);
        if (!fsProject.exists) {
          throw UnsupportedError('project not found');
        }
        fsProject.name.setValue(project.name.v);
        txn.refUpdate(fsProjectRef, fsProject);
      });
    }
  }
}

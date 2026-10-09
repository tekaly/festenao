import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';

export 'package:festenao_common/src/data/project_modules.dart';

/// The modules of a project document.
extension FsProjectModulesExt on FsProject {
  /// Whether [module] is on in the project (every module when
  /// [FsProject.modules] is null).
  bool hasModule(String module) => festenaoProjectHasModule(modules.v, module);
}

/// The modules of the festenao projects.
extension FestenaoFirestoreDatabaseModulesExt on FestenaoFirestoreDatabase {
  /// Sets the modules on in the project [projectId], every module when
  /// [modules] is null; the project admins can write it.
  ///
  /// The local mirror (`SdbUserProject.modules`) follows on the next sync of
  /// the user projects (`UserProjectsSdbSynchronizer.syncOne`).
  Future<void> setProjectModules(String projectId, List<String>? modules) =>
      projectDb.fsEntityRef(projectId).raw(firestore).set({
        'modules': modules,
      }, SetOptions(merge: true));

  /// Sets the modules of [projectId] (see [setProjectModules]) and updates
  /// its local mirror in [projectsSdb] for [userId] right away.
  Future<void> setProjectModulesAndMirror(
    String projectId,
    List<String>? modules, {
    required UserProjectsSdb projectsSdb,
    required String userId,
  }) async {
    await setProjectModules(projectId, modules);
    var synchronizer = UserProjectsSdbSynchronizer(
      projectsSdb: projectsSdb,
      fsProjects: projectDb,
    );
    try {
      await synchronizer.syncOne(userId: userId, projectId: projectId);
    } finally {
      synchronizer.dispose();
    }
  }

  /// The modules on in the project [projectId], null when every module is.
  Future<List<String>?> getProjectModules(String projectId) async =>
      (await projectDb.fsEntityRef(projectId).get(firestore)).modules.v;
}

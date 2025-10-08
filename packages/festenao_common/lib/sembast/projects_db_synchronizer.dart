import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/sembast/projects_db.dart';
import 'package:tkcms_common/tkcms_audi.dart';

/// Projects db synchronizer helper for syncing projects between Firestore and local database.
class ProjectsDbSynchronizer with AutoDisposeMixin {
  Firestore get firestore => fsProjects.firestore;
  final ProjectsDb projectsDb;

  /// The Firestore entity access for projects.
  final TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> fsProjects;

  /// Creates a new [ProjectsDbSynchronizer] with the given [projectsDb] and [fsProjects].
  ProjectsDbSynchronizer({required this.projectsDb, required this.fsProjects});

  /// Disposes the synchronizer and cancels all subscriptions.
  void dispose() {
    audiDisposeAll();
  }

  /// Syncs a single project for the given [userId] and [projectId].
  Future<void> syncOne({
    required String userId,
    required String projectId,
  }) async {
    var fsProject = await fsProjects.fsEntityRef(projectId).get(firestore);
    var fsUserAccess = await fsProjects
        .fsUserEntityAccessRef(userId, projectId)
        .get(firestore);

    var exists = fsProject.exists && fsProject.deleted.v != true;
    await projectsDb.ready;
    var db = projectsDb.db;
    await db.transaction((txn) async {
      if (exists) {
        var dbProjects = await dbProjectStore
            .query(
              finder: projectsDb.getProjectFinder(
                userId: userId,
                projectId: projectId,
              ),
            )
            .getRecords(txn);
        // Delete other if more than one
        if (dbProjects.length > 1) {
          await dbProjectStore
              .records(dbProjects.skip(1).map((item) => item.id))
              .delete(txn);
        }
        var dbProject = dbProjects.firstOrNull;
        var needUpdate = dbProject == null;
        if (dbProject != null) {
          if (dbProject.name.v != fsProject.name.v ||
              !TkCmsCvUserAccessCommon.equals(fsUserAccess, dbProject)) {
            needUpdate = true;
          }
        }

        if (needUpdate) {
          var newDbProject = DbProject()
            ..uid.v = projectId
            ..userId.v = userId
            ..name.v = fsProject.name.v
            ..copyFrom(fsUserAccess);
          if (dbProject != null) {
            await dbProjectStore.record(dbProject.id).put(txn, newDbProject);
          } else {
            await dbProjectStore.add(txn, newDbProject);
          }
        }
      } else {
        await dbProjectStore.delete(
          txn,
          finder: projectsDb.getProjectFinder(
            userId: userId,
            projectId: projectId,
          ),
        );
      }
    });
  }
}

/// Projects db synchronizer helper for auto-syncing a single project.
class ProjectsDbSingleProjectAutoSynchronizer with AutoDisposeMixin {
  /// The local projects database.
  final ProjectsDb projectsDb;

  /// The project ID to sync.
  final String projectId;

  /// The user ID for the project.
  final String userId;

  /// The Firestore entity access for projects.
  final TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> fsProjects;

  /// Creates a new [ProjectsDbSingleProjectAutoSynchronizer] with the given parameters.
  ProjectsDbSingleProjectAutoSynchronizer({
    required this.projectsDb,
    required this.fsProjects,
    required this.projectId,
    required this.userId,
  }) {
    () async {
      audiAddStreamSubscription(
        streamJoin2OrError(
          projectsDb.onProject(projectId, userId: userId),
          dbProjectStore.record(projectId).onRecord(projectsDb.db),
        ).listen((dbProject) {
          // ignore: avoid_print
          print('dbProject: $dbProject');
        }),
      );
    }();
  }

  /// Disposes the synchronizer and cancels all subscriptions.
  void dispose() {
    audiDisposeAll();
  }
}

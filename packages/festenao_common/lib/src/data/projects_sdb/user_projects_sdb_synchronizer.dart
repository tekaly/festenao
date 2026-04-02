import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:tkcms_common/tkcms_audi.dart';

/// debug flag
var debugProjectsDbSynchronizer = false; // devWarning(true); // false;

void _log(String message) {
  // ignore: avoid_print
  print('/user_projects_sync: $message');
}

/// Projects db synchronizer helper for syncing projects between Firestore and local database.
class UserProjectsSdbSynchronizer with AutoDisposeMixin {
  /// The firestore instance.
  Firestore get firestore => fsProjects.firestore;

  /// The local projects database.
  final UserProjectsSdb projectsDb;

  /// The Firestore entity access for projects.
  final TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> fsProjects;

  /// Creates a new [UserProjectsSdbSynchronizer] with the given [projectsDb] and [fsProjects].
  UserProjectsSdbSynchronizer({
    required this.projectsDb,
    required this.fsProjects,
  });

  /// Disposes the synchronizer and cancels all subscriptions.
  void dispose() {
    audiDisposeAll();
  }

  /// Syncs a single project for the given [userId] and [projectId].
  Future<void> syncOne({
    required String userId,
    required String projectId,
  }) async {
    if (debugProjectsDbSynchronizer) {
      _log('syncOne $userId $projectId');
    }
    var fsProject = await fsProjects.fsEntityRef(projectId).get(firestore);
    var fsUserAccess = await fsProjects
        .fsUserEntityAccessRef(userId, projectId)
        .get(firestore);
    if (debugProjectsDbSynchronizer) {
      _log('fsProject $fsProject');
    }
    var exists = fsProject.exists && fsProject.deleted.v != true;
    await projectsDb.ready;
    var db = projectsDb.db;
    await dbProjectStore.inTransaction(db, SdbTransactionMode.readWrite, (
      txn,
    ) async {
      var projectIndexId = userProjectIndex.record(userId, projectId);
      if (exists) {
        var dbProjects = await projectIndexId.findObjects(txn);
        if (dbProjects.isNotEmpty) {
          var ids = dbProjects.skip(1).map((item) => item.id);
          if (debugProjectsDbSynchronizer) {
            _log('Deleting $ids');
          }
          // Delete other if more than one
          if (dbProjects.length > 1) {
            await dbProjectStore.records(ids).delete(txn);
          }
        }
        var dbProject = dbProjects.firstOrNull;
        var needUpdate = dbProject == null;
        if (dbProject != null) {
          var nameDifferent = dbProject.name.v != fsProject.name.v;
          var rightsDifferent = !TkCmsCvUserAccessCommon.equals(
            fsUserAccess,
            dbProject,
          );
          if (nameDifferent || rightsDifferent) {
            if (debugProjectsDbSynchronizer) {
              if (nameDifferent && rightsDifferent) {
                _log('Updating $dbProject');
              }
              if (nameDifferent) {
                _log('Updating name ${dbProject.name.v}');
              }
              if (rightsDifferent) {
                _log('Updating rights $fsUserAccess');
              }
            }
            needUpdate = true;
          }
        }
        if (needUpdate) {
          var newDbProject = SdbUserProject()
            ..uid.v = projectId
            ..userId.v = userId
            ..name.v = fsProject.name.v
            ..copyFrom(fsUserAccess);
          if (dbProject != null) {
            await dbProjectStore.record(dbProject.id).put(txn, newDbProject);
          } else {
            var id = await dbProjectStore.add(txn, newDbProject);
            if (debugProjectsDbSynchronizer) {
              _log('Created $id $newDbProject');
            }
          }
        }
      } else {
        if (debugProjectsDbSynchronizer) {
          _log('Deleting $projectIndexId');

          // Delete if not exists
        }
        await projectIndexId.delete(txn);
      }
    });
  }
}

/// Projects db synchronizer helper for auto-syncing a single project.
class ProjectsDbSingleProjectAutoSynchronizer with AutoDisposeMixin {
  /// The local projects database.
  final UserProjectsSdb projectsDb;

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
          projectsDb.onProjectsUserReady(userId: userId),
          projectsDb.onProject(projectId, userId: userId),
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

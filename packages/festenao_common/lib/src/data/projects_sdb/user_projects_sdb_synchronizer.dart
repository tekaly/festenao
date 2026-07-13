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
  final UserProjectsSdb projectsSdb;

  /// The Firestore entity access for projects.
  final TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> fsProjects;

  /// Creates a new [UserProjectsSdbSynchronizer] with the given [projectsSdb] and [fsProjects].
  UserProjectsSdbSynchronizer({
    required this.projectsSdb,
    required this.fsProjects,
  });

  /// Disposes the synchronizer and cancels all subscriptions.
  void dispose() {
    audiDisposeAll();
  }

  /// Builds the local projects database content for [userId] from the
  /// firestore user access list (one shot, easy to trigger from the UI).
  ///
  /// [identityId] is the local database key (defaults to [userId]).
  Future<void> syncUserProjects({
    required String userId,
    String? identityId,
  }) async {
    identityId ??= userId;
    if (debugProjectsDbSynchronizer) {
      _log('syncUserProjects $userId');
    }
    var userAccessList = await fsProjects
        .fsUserEntityAccessCollectionRef(userId)
        .query()
        .get(firestore);
    var fsProjectList = <FsProject>[];
    for (var userAccess in userAccessList) {
      try {
        fsProjectList.add(
          await fsProjects.fsEntityRef(userAccess.id).get(firestore),
        );
      } catch (e) {
        // Some error might happen (access denied) so skip the project.
        if (debugProjectsDbSynchronizer) {
          _log('error getting project ${userAccess.id}: $e');
        }
      }
    }
    await applyUserProjects(
      userId: userId,
      identityId: identityId,
      userAccessList: userAccessList,
      fsProjectList: fsProjectList,
    );
  }

  /// Applies the firestore [fsProjectList] and matching [userAccessList] to
  /// the local database: deletes the projects no longer accessible, adds or
  /// updates the others and marks the user as ready.
  ///
  /// [identityId] is the local database key (defaults to [userId]).
  Future<void> applyUserProjects({
    required String userId,
    String? identityId,
    required List<TkCmsFsUserAccess> userAccessList,
    required List<FsProject> fsProjectList,
  }) async {
    var dbIdentityId = identityId ?? userId;
    var projectsDb = projectsSdb;
    await projectsDb.ready;
    var accessMap = <String, TkCmsFsUserAccess>{
      for (var userAccess in userAccessList) userAccess.id: userAccess,
    };
    var dbProjects = await projectsDb.getProjects(userId: dbIdentityId);
    var projectMap = {
      for (var project in dbProjects)
        if (project.uid.isNotNull) project.fsId: project,
    };
    var toDelete = dbProjects.map((e) => e.id).toSet();
    var toSet = <SdbUserProject>[];
    for (var fsProject in fsProjectList) {
      var uid = fsProject.id;
      var userProjectAccess = accessMap[uid];
      if (userProjectAccess == null) {
        continue;
      }
      if (!fsProject.exists || fsProject.deleted.v == true) {
        continue;
      }
      var newDbProject = SdbUserProject()
        ..fromFirestore(
          fsProject: fsProject,
          projectAccess: userProjectAccess,
          userId: dbIdentityId,
        );
      var existing = projectMap[uid];
      if (existing != null) {
        toDelete.remove(existing.id);
        if (existing.needUpdate(newDbProject)) {
          existing.copyFrom(newDbProject);
          toSet.add(existing);
        }
      } else {
        toSet.add(newDbProject);
      }
    }
    if (debugProjectsDbSynchronizer) {
      _log('applyUserProjects toDelete $toDelete toSet $toSet');
    }
    await projectsDb.db.inScvStoresTransaction(
      [dbProjectUserStore, dbProjectStore],
      SdbTransactionMode.readWrite,
      (txn) async {
        for (var id in toDelete) {
          await dbProjectStore.record(id).delete(txn);
        }
        for (var project in toSet) {
          if (project.idOrNull == null) {
            await dbProjectStore.add(txn, project);
          } else {
            await dbProjectStore.record(project.id).put(txn, project);
          }
        }
        await projectsDb.clientSetCurrentIdentityId(txn, dbIdentityId);
      },
    );
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
    await projectsSdb.ready;
    var db = projectsSdb.db;
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

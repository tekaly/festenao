import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
//import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:festenao_admin_base_app/sembast/sembast.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:flutter/foundation.dart';
import 'package:tkcms_common/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Projects screen bloc state
class ProjectsScreenBlocState {
  /// User
  FirebaseUser? get user => identity?.user;
  final TkCmsFbIdentity? identity;

  /// Projects
  final List<SdbUserProject> projects;

  /// Projects screen bloc state
  ProjectsScreenBlocState({required this.projects, this.identity});
}

/// Projects screen bloc
class ProjectsSdbScreenBloc
    extends AutoDisposeStateBaseBloc<ProjectsScreenBlocState> {
  final UserProjectsSdb projectsDb;
  // ignore: cancel_subscriptions
  StreamSubscription? _dbSubscription,
      // ignore: cancel_subscriptions
      _firestoreSubscription,
      // ignore: cancel_subscriptions
      _projectDetailsSubscription;
  String? _dbIdentityId;

  late final _lock = Lock(); // globalProjectsBloc.syncLock;
  final _fsLock = Lock();
  final bool selectMode;

  Future<void> setCurrentIdentityReady(
    UserProjectsSdb projectsDb,

    String identityId,
  ) async {
    await projectsDb.clientSetCurrentIdentityId(projectsDb.db, identityId);
  }

  /// Projects screen bloc
  ProjectsSdbScreenBloc({required this.projectsDb, this.selectMode = false}) {
    () async {
      audiAddStreamSubscription(
        globalTkCmsFbIdentityBloc.state.listen((state) {
          _lock.synchronized(() async {
            var identity = state.identity;

            var identityId =
                identity?.userOrAccountId; // updated to user?.localId
            if (identity != null) {
              if (identityId != null && identityId != _dbIdentityId) {
                _dbIdentityId = identityId;
                audiDispose(_dbSubscription);
                audiDispose(_firestoreSubscription);
                audiDispose(_projectDetailsSubscription);
                var projectsDb = this.projectsDb;
                _dbSubscription = audiAddStreamSubscription(
                  projectsDb.onProjects(userId: identityId).listen((projects) {
                    add(
                      ProjectsScreenBlocState(
                        projects: projects,
                        identity: identity,
                      ),
                    );
                  }),
                );

                /// Build from firestore
                var fsDb = globalFestenaoFirestoreDatabase.projectDb;

                var userId = identity.userId;
                if (userId != null) {
                  _firestoreSubscription = audiAddStreamSubscription(
                    fsDb
                        .fsUserEntityAccessCollectionRef(userId)
                        .onSnapshotsSupport(fsDb.firestore)
                        .listen(
                          (list) async {
                            var fsProjectUids = list.map((e) => e.id).toList();
                            var fsProjectAccessMap =
                                <String, TkCmsFsUserAccess>{};
                            for (var item in list) {
                              fsProjectAccessMap[item.id] = item;
                            }

                            audiDispose(_projectDetailsSubscription);

                            if (fsProjectUids.isEmpty) {
                              await projectsDb.ready;
                              await projectsDb.deleteProjects(userId: userId);
                              await dbProjectUserStore
                                  .record(identityId)
                                  .put(
                                    projectsDb.db,
                                    SdbProjectsUser()
                                      ..readyTimestamp.v = DbTimestamp.now(),
                                  );

                              return;
                            }
                            // Some error might happen (access) so handle it.
                            _projectDetailsSubscription = audiAddStreamSubscription(
                              streamJoinAllOrError(
                                fsProjectUids
                                    .map(
                                      (id) => (fsDb.fsEntityCollectionRef
                                          .doc(id)
                                          .onSnapshotSupport(fsDb.firestore)),
                                    )
                                    .toList(),
                              ).listen(
                                (items) {
                                  _fsLock.synchronized(() async {
                                    // var ProjectsUser = await dbProjectUserStore.record(userId).get(ProjectsDb.db);
                                    var dbProjects = await projectsDb
                                        .getProjects(userId: identityId);
                                    var projectMap = {
                                      for (var project in dbProjects)
                                        if (project.uid.isNotNull)
                                          project.fsId: project,
                                    };
                                    var toDelete = dbProjects
                                        .map((e) => e.id)
                                        .toSet();
                                    var toSet = <SdbUserProject>[];
                                    for (var item in items) {
                                      if (item.error == null) {
                                        var fsProject = item.value!;
                                        var uid = fsProject.id;
                                        var existing = projectMap[uid];
                                        var userProjectAccess =
                                            fsProjectAccessMap[uid];
                                        if (userProjectAccess == null) {
                                          // ? this might delete id
                                          continue;
                                        }
                                        if (existing != null) {
                                          if (fsProject.deleted.v != true) {
                                            toDelete.remove(existing.id);
                                            var newDbProject = SdbUserProject()
                                              ..fromFirestore(
                                                fsProject: fsProject,
                                                projectAccess:
                                                    userProjectAccess,
                                                userId: identityId,
                                              );
                                            if (existing.needUpdate(
                                              newDbProject,
                                            )) {
                                              existing.copyFrom(newDbProject);
                                              toSet.add(existing);
                                            }
                                          }
                                        } else {
                                          var newDbProject = SdbUserProject()
                                            ..fromFirestore(
                                              fsProject: fsProject,
                                              projectAccess: userProjectAccess,
                                              userId: identityId,
                                            );
                                          toSet.add(newDbProject);
                                        }
                                      }
                                    }

                                    await projectsDb.db.inScvStoresTransaction(
                                      [dbProjectUserStore, dbProjectStore],
                                      SdbTransactionMode.readWrite,
                                      (txn) async {
                                        for (var id in toDelete) {
                                          await dbProjectStore
                                              .record(id)
                                              .delete(txn);
                                        }
                                        for (var project in toSet) {
                                          if (project.idOrNull == null) {
                                            project = await dbProjectStore.add(
                                              txn,
                                              project,
                                            );
                                          } else {
                                            await dbProjectStore
                                                .record(project.id)
                                                .put(txn, project);
                                          }
                                          await dbProjectStore
                                              .record(project.id)
                                              .put(txn, project);
                                        }
                                        await projectsDb
                                            .clientSetCurrentIdentityId(
                                              txn,
                                              userId,
                                            );
                                      },
                                    );
                                  });
                                },
                                onError: (error) {
                                  if (kDebugMode) {
                                    print('error getting Project details');
                                  }
                                },
                              ),
                            );
                          },
                          onError: (error) {
                            if (kDebugMode) {
                              print(
                                'error listing ${fsDb.fsUserEntityAccessCollectionRef(identityId).path}',
                              );
                            }
                          },
                        ),
                  );
                } else {
                  await projectsDb.ready;
                  await setCurrentIdentityReady(projectsDb, identityId);
                }
              }
            } else {
              if (identityId == null) {
                _dbIdentityId = null;
                add(ProjectsScreenBlocState(projects: []));
              }
            }
          });
        }),
      );
    }();
  }
}

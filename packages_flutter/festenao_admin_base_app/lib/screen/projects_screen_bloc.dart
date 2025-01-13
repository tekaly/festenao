import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:festenao_admin_base_app/sembast/sembast.dart';
import 'package:festenao_admin_base_app/utils/sembast_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:tekartik_common_utils/stream/stream_join.dart';
import 'package:tkcms_common/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

import '../firebase/firebase.dart';

/// Projects screen bloc state
class ProjectsScreenBlocState {
  /// User
  final FirebaseUser? user;

  /// Projects
  final List<DbProject> projects;

  /// Projects screen bloc state
  ProjectsScreenBlocState({required this.projects, this.user});
}

/// Projects screen bloc
class ProjectsScreenBloc
    extends AutoDisposeStateBaseBloc<ProjectsScreenBlocState> {
  // ignore: cancel_subscriptions
  StreamSubscription? _dbSubscription,
      // ignore: cancel_subscriptions
      _firestoreSubscription,
      // ignore: cancel_subscriptions
      _projectDetailsSubscription;
  String? _dbUserId;
  bool _gotFirstUser = false;
  late final _lock = Lock(); // globalProjectsBloc.syncLock;
  final _fsLock = Lock();

  /// Projects screen bloc
  ProjectsScreenBloc() {
    audiAddStreamSubscription(
        globalAdminAppFirebaseContext.auth.onCurrentUser.listen((user) {
      _lock.synchronized(() async {
        var userId = user?.uid;
        if (userId != _dbUserId || !_gotFirstUser) {
          _gotFirstUser = true;
          _dbUserId = userId;
          audiDispose(_dbSubscription);
          audiDispose(_firestoreSubscription);
          audiDispose(_projectDetailsSubscription);

          if (userId == null) {
            _dbSubscription = audiAddStreamSubscription(
                globalProjectsDb.onLocalProjects().listen((projects) {
              add(ProjectsScreenBlocState(projects: projects, user: user));
            }));
          } else {
            _dbSubscription = audiAddStreamSubscription(globalProjectsDb
                .onProjects(userId: _dbUserId!)
                .listen((projects) {
              add(ProjectsScreenBlocState(projects: projects, user: user));
            }));

            /// Build from firestore
            var fsDb = globalNotelioFirestoreDatabase.projectDb;
            var projectsDb = globalProjectsDb;
            _firestoreSubscription = audiAddStreamSubscription(fsDb
                .fsUserEntityAccessCollectionRef(userId)
                .onSnapshots(fsDb.firestore)
                .listen((list) async {
              var projectUids = list.map((e) => e.id).toList();
              var projectAccessMap = <String, TkCmsFsUserAccess>{};
              for (var item in list) {
                projectAccessMap[item.id] = item;
              }

              audiDispose(_projectDetailsSubscription);

              if (projectUids.isEmpty) {
                await projectsDb.ready;
                await projectsDb.db.transaction((txn) async {
                  await dbProjectStore.delete(txn,
                      finder: Finder(
                          filter: Filter.equals(
                              dbProjectModel.userId.name, userId)));
                  await dbProjectUserStore.record(userId).put(txn,
                      DbProjectUser()..readyTimestamp.v = DbTimestamp.now());
                });
                return;
              }
              // Some error might happen (access) so handle it.
              _projectDetailsSubscription = audiAddStreamSubscription(
                  streamJoinAllOrError(projectUids
                          .map((id) => (fsDb.fsEntityCollectionRef
                              .doc(id)
                              .onSnapshot(fsDb.firestore)))
                          .toList())
                      .listen((items) {
                _fsLock.synchronized(() async {
                  // var ProjectsUser = await dbProjectUserStore.record(userId).get(ProjectsDb.db);
                  var dbProjects = await projectsDb.getExistingSyncedProjects(
                      userId: userId);
                  var projectMap = {
                    for (var project in dbProjects) project.uid.v!: project
                  };
                  var toDelete = dbProjects.map((e) => e.id).toSet();
                  var toSet = <DbProject>[];
                  for (var item in items) {
                    if (item.error == null) {
                      var fsProject = item.value!;
                      var uid = fsProject.id;
                      var existing = projectMap[uid];
                      var userProjectAccess = projectAccessMap[uid];
                      if (userProjectAccess == null) {
                        // ? this might delete id
                        continue;
                      }
                      if (existing != null) {
                        if (fsProject.deleted.v != true) {
                          toDelete.remove(existing.id);
                          var newDbProject = DbProject()
                            ..fromFirestore(
                                fsProject: fsProject,
                                projectAccess: userProjectAccess,
                                userId: userId);
                          if (existing.needUpdate(newDbProject)) {
                            existing.copyFrom(newDbProject);
                            toSet.add(existing);
                          }
                        }
                      } else {
                        var newDbProject = DbProject()
                          ..fromFirestore(
                              fsProject: fsProject,
                              projectAccess: userProjectAccess,
                              userId: userId);
                        toSet.add(newDbProject);
                      }
                    }
                  }

                  await projectsDb.db.transaction((txn) async {
                    for (var id in toDelete) {
                      await dbProjectStore.record(id).delete(txn);
                    }
                    for (var project in toSet) {
                      if (project.idOrNull == null) {
                        await dbProjectStore.add(txn, project);
                      } else {
                        await dbProjectStore
                            .record(project.id)
                            .put(txn, project);
                      }
                      await dbProjectStore.record(project.id).put(txn, project);
                    }
                    await dbProjectUserStore.record(userId).put(txn,
                        DbProjectUser()..readyTimestamp.v = DbTimestamp.now());
                  });
                });
              }, onError: (error) {
                if (kDebugMode) {
                  print('error getting Project details');
                }
              }));
            }, onError: (error) {
              if (kDebugMode) {
                print(
                    'error listing ${fsDb.fsUserEntityAccessCollectionRef(userId).path}');
              }
            }));
          }
        } else {
          if (!state.hasValue && userId == null) {
            add(ProjectsScreenBlocState(projects: []));
          }
        }
      });
    }));
  }
}

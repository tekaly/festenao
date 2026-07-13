import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
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
  TkCmsFbIdentity? _identity;

  late final _lock = Lock(); // globalProjectsBloc.syncLock;
  final _fsLock = Lock();
  final bool selectMode;

  UserProjectsSdbSynchronizer get _synchronizer => UserProjectsSdbSynchronizer(
    projectsSdb: projectsDb,
    fsProjects: globalFestenaoFirestoreDatabase.projectDb,
  );

  Future<void> setCurrentIdentityReady(
    UserProjectsSdb projectsDb,

    String identityId,
  ) async {
    await projectsDb.clientSetCurrentIdentityId(projectsDb.db, identityId);
  }

  /// Trigger a one shot user access synchronization (rebuild the local
  /// projects list from the firestore access list). No-op when not
  /// authenticated.
  Future<void> syncUserProjects() async {
    var identity = _identity;
    var userId = identity?.userId;
    if (identity == null || userId == null) {
      return;
    }
    await _fsLock.synchronized(() async {
      await _synchronizer.syncUserProjects(
        userId: userId,
        identityId: identity.userOrAccountId,
      );
    });
  }

  /// Projects screen bloc
  ProjectsSdbScreenBloc({required this.projectsDb, this.selectMode = false}) {
    () async {
      audiAddStreamSubscription(
        globalTkCmsFbIdentityBloc.state.listen((state) {
          _lock.synchronized(() async {
            var identity = state.identity;
            _identity = identity;

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

                            audiDispose(_projectDetailsSubscription);

                            if (fsProjectUids.isEmpty) {
                              await _fsLock.synchronized(() async {
                                await _synchronizer.applyUserProjects(
                                  userId: userId,
                                  identityId: identityId,
                                  userAccessList: list,
                                  fsProjectList: [],
                                );
                              });
                              return;
                            }
                            // Some error might happen (access) so handle it.
                            _projectDetailsSubscription =
                                audiAddStreamSubscription(
                                  streamJoinAllOrError(
                                    fsProjectUids
                                        .map(
                                          (id) => (fsDb.fsEntityCollectionRef
                                              .doc(id)
                                              .onSnapshotSupport(
                                                fsDb.firestore,
                                              )),
                                        )
                                        .toList(),
                                  ).listen(
                                    (items) {
                                      _fsLock.synchronized(() async {
                                        var fsProjectList = items
                                            .where((item) => item.error == null)
                                            .map((item) => item.value!)
                                            .toList();
                                        await _synchronizer.applyUserProjects(
                                          userId: userId,
                                          identityId: identityId,
                                          userAccessList: list,
                                          fsProjectList: fsProjectList,
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

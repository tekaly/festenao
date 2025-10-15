import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/sembast/projects_db_bloc.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/sembast/projects_db_synchronizer.dart';
import 'package:tekaly_sembast_synced/synced_db_firestore.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';

class ProjectRootScreenBlocState {
  final TkCmsFbIdentity? identity;
  final DbProject? project;

  ProjectRootScreenBlocState({this.project, this.identity});
}

class ProjectRootScreenBloc
    extends AutoDisposeStateBaseBloc<ProjectRootScreenBlocState> {
  FestenaoAdminAppProjectContext get projectContext =>
      ByProjectIdAdminAppProjectContext(projectId: projectId);
  final String projectId;
  late final _lock = Lock();
  var _syncTriedOnce = false;
  String get userId => firebaseUser!.uid;
  FirebaseUser? firebaseUser;
  String? _dbIdentityId;
  StreamSubscription? _projectSubscription;

  /// Explicit db bloc to access the database
  //late   AdminAppProjectContextDbBloc dbBloc = audiAddDisposable(AdminAppProjectContextDbBloc(projectContext: projectContext));

  ProjectRootScreenBloc({required this.projectId}) {
    () async {
      /*
      if (globalProjectsDbBloc is SingleCompatProjectDbBloc) {
        add(
          ProjectRootScreenBlocState(
            project: DbProject()
              ..uid.v = ByProjectIdAdminAppProjectContext.mainProjectId,
            identity: null,
          ),
        );
        return;
      }*/

      audiAddStreamSubscription(
        globalTkCmsFbIdentityBloc.state.listen((state) {
          _lock.synchronized(() async {
            var identity = state.identity;

            if (identity == null) {
              add(ProjectRootScreenBlocState());
            } else {
              var newDbIdentityId = identity.userLocalId;

              if (newDbIdentityId != _dbIdentityId) {
                _projectSubscription?.cancel().unawait();
                _dbIdentityId = newDbIdentityId;

                var projectsDb = globalProjectsDbOrNull;
                if (projectsDb != null) {
                  _projectSubscription = audiAddStreamSubscription(
                    globalProjectsDb
                        .onProject(projectId, userId: newDbIdentityId!)
                        .listen((event) async {
                          var project = event;
                          add(
                            ProjectRootScreenBlocState(
                              project: project,
                              identity: identity,
                            ),
                          );
                          if (project == null && !_syncTriedOnce) {
                            _syncTriedOnce = true;
                            await _syncProjectInProjectsDb();
                          }
                        }),
                  );
                } else {
                  // No projects db, assume single project mode
                  add(
                    ProjectRootScreenBlocState(
                      project: DbProject()..uid.v = projectId,
                      identity: identity,
                    ),
                  );
                }
              }
            }
          });
        }),
      );
    }();
  }

  Future<void> _syncProjectInProjectsDb() async {
    var synchronizer = ProjectsDbSynchronizer(
      projectsDb: globalProjectsDb,
      fsProjects: globalFestenaoFirestoreDatabase.projectDb,
    );
    await synchronizer.syncOne(projectId: projectId, userId: _dbIdentityId!);
  }

  Future<SyncedSyncStat> sync() async {
    var projectDbBloc = globalProjectsDbBloc;
    var identityId = _dbIdentityId;
    if (identityId == null) {
      throw StateError('No identity');
    }

    /// Only for single project mode with a predefined synced db
    if (projectDbBloc is SingleCompatProjectDbBloc) {
      var syncedDb = projectDbBloc.syncedDb;

      var synchronizer = SyncedDbSynchronizer(
        db: syncedDb,
        source: SyncedSourceFirestore(
          firestore: globalFestenaoFirestoreDatabase.firestore,
          rootPath: globalFestenaoAppFirebaseContext.firestoreRootPath,
        ),
      );
      return await synchronizer.sync();
      //(globalProjectsDbBloc as SingleProjectDbBloc).syncedDb.sync();
    } else if (projectDbBloc is MultiProjectsDbBloc) {
      var contentDb = await projectDbBloc.grabContentDbOrNull(
        userId: identityId,
        projectId: projectId,
      );
      if (contentDb == null) {
        throw StateError('No content db for $projectId');
      }
      return await contentDb.contentDb.synchronize();
    }
    throw StateError('Cannot sync for $projectDbBloc');
  }
}

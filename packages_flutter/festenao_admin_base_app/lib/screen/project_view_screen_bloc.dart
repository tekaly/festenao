import 'dart:async';

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tekartik_common_utils/stream/stream_join.dart';

class ProjectViewScreenBlocState {
  final TkCmsFbIdentity? identity;
  FirebaseUser? get user => identity?.user;
  final DbProject? project;
  final bool dbProjectReady; // can be null be ready

  /// Optional, if the project is not found in the local database
  final FsProject? fsProject;

  /// Project view screen bloc state
  final TkCmsFsUserAccess? fsUserAccess;

  ProjectViewScreenBlocState({
    this.project,
    this.identity,
    this.fsProject,
    this.fsUserAccess,
    bool? dbProjectReady,
  }) : dbProjectReady = dbProjectReady ?? (project != null);
}

class ProjectViewScreenBloc
    extends AutoDisposeStateBaseBloc<ProjectViewScreenBlocState> {
  final String projectId;

  // ignore: cancel_subscriptions
  StreamSubscription? fsSubscription;
  String get userId => firebaseUser!.uid;
  TkCmsFbIdentity? identity;
  FirebaseUser? get firebaseUser => identity?.user;
  ProjectViewScreenBloc({required this.projectId}) {
    () async {
      var fbIdentity = identity =
          ((await globalTkCmsFbIdentityBloc.state.first).identity);
      var user = identity?.user;
      if (fbIdentity == null) {
        add(ProjectViewScreenBlocState());
      } else {
        var userOrLocalId = fbIdentity.userLocalId!;
        var fsDb = globalFestenaoFirestoreDatabase.projectDb;
        var firestore = globalFestenaoFirestoreDatabase.firestore;
        audiAddStreamSubscription(
          globalProjectsDb.onProject(projectId, userId: userOrLocalId).listen((
            event,
          ) {
            var dbProject = event;
            if (dbProject == null) {
              if (user != null) {
                fsSubscription = audiAddStreamSubscription(
                  streamJoin2OrError(
                    fsDb.fsEntityRef(projectId).onSnapshotSupport(firestore),
                    fsDb
                        .fsUserEntityAccessRef(userId, projectId)
                        .onSnapshotSupport(firestore),
                  ).listen((event) {
                    var values = event.values;
                    var fsProject = values.$1;
                    var fsUserAccess = values.$2;
                    add(
                      ProjectViewScreenBlocState(
                        project: dbProject,
                        identity: identity,
                        fsProject: fsProject,
                        fsUserAccess: fsUserAccess,
                        dbProjectReady: true,
                      ),
                    );
                  }),
                );
              } else {
                fsSubscription = audiAddStreamSubscription(
                  fsDb
                      .fsEntityRef(projectId)
                      .onSnapshotSupport(firestore)
                      .listen((event) {
                        var fsProject = event;
                        var fsUserAccess = TkCmsFsUserAccess.admin();
                        add(
                          ProjectViewScreenBlocState(
                            project: dbProject,
                            identity: identity,
                            fsProject: fsProject,
                            fsUserAccess: fsUserAccess,
                            dbProjectReady: true,
                          ),
                        );
                      }),
                );
              }
            } else {
              add(
                ProjectViewScreenBlocState(
                  project: dbProject,
                  identity: identity,
                  dbProjectReady: true,
                ),
              );
            }
          }),
        );
      }
    }();
  }

  Future<void> deleteProject(DbProject project) async {
    await globalFestenaoFirestoreDatabase.projectDb.deleteEntity(
      project.fsId,
      userId: userId,
    );
  }

  Future<void> leaveProject(DbProject project) async {
    await globalFestenaoFirestoreDatabase.projectDb.leaveEntity(
      project.fsId,
      userId: userId,
    );
  }
}

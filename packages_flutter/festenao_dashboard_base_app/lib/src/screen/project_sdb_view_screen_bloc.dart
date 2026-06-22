import 'dart:async';

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
//import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tekartik_common_utils/stream/stream_join.dart';

class ProjectSdbViewScreenBlocState {
  final TkCmsFbIdentity? identity;
  FirebaseUser? get user => identity?.user;
  final SdbUserProject? project;
  final bool dbProjectReady; // can be null be ready

  /// Optional, if the project is not found in the local database
  final FsProject? fsProject;

  /// Project view screen bloc state
  final TkCmsFsUserAccess? fsUserAccess;

  ProjectSdbViewScreenBlocState({
    this.project,
    this.identity,
    this.fsProject,
    this.fsUserAccess,
    bool? dbProjectReady,
  }) : dbProjectReady = dbProjectReady ?? (project != null);
}

class ProjectSdbViewScreenBloc
    extends AutoDisposeStateBaseBloc<ProjectSdbViewScreenBlocState> {
  final String projectId;
  final UserProjectsSdb projectsDb;
  // ignore: cancel_subscriptions
  StreamSubscription? fsSubscription;
  String get userId => firebaseUser!.uid;
  TkCmsFbIdentity? identity;
  FirebaseUser? get firebaseUser => identity?.user;
  ProjectSdbViewScreenBloc({
    required this.projectId,
    required this.projectsDb,
  }) {
    () async {
      var fbIdentity = identity =
          ((await globalTkCmsFbIdentityBloc.state.first).identity);
      var user = identity?.user;
      if (fbIdentity == null) {
        add(ProjectSdbViewScreenBlocState());
      } else {
        var userOrLocalId = fbIdentity.userLocalId!;
        var fsDb = globalFestenaoFirestoreDatabase.projectDb;
        var firestore = globalFestenaoFirestoreDatabase.firestore;
        audiAddStreamSubscription(
          projectsDb.onProject(projectId, userId: userOrLocalId).listen((
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
                      ProjectSdbViewScreenBlocState(
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
                          ProjectSdbViewScreenBlocState(
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
                ProjectSdbViewScreenBlocState(
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

  Future<void> deleteProject(SdbUserProject project) async {
    await globalFestenaoFirestoreDatabase.projectDb.deleteEntity(
      project.fsId,
      userId: userId,
    );
  }

  Future<void> leaveProject(SdbUserProject project) async {
    await globalFestenaoFirestoreDatabase.projectDb.leaveEntity(
      project.fsId,
      userId: userId,
    );
  }
}

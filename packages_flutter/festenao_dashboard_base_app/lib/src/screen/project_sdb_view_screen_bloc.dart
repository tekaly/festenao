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
  final TkCmsFsEntity? fsProject;

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

  /// Local projects db, null for any entity that has no local mirror (a
  /// songbook...): the firestore entity and access are then used directly.
  final UserProjectsSdb? projectsDb;

  /// Entity shown, defaults to the festenao project entity.
  final TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity>? entityAccess;

  /// The entity access in use.
  TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity> get fsDb =>
      entityAccess ?? globalFestenaoFirestoreDatabase.projectDb;
  // ignore: cancel_subscriptions
  StreamSubscription? fsSubscription;
  String get userId => firebaseUser!.uid;
  TkCmsFbIdentity? identity;
  FirebaseUser? get firebaseUser => identity?.user;
  ProjectSdbViewScreenBloc({
    required this.projectId,
    this.projectsDb,
    this.entityAccess,
  }) {
    () async {
      var fbIdentity = identity =
          ((await globalTkCmsFbIdentityBloc.state.first).identity);
      var user = identity?.user;
      if (fbIdentity == null) {
        add(ProjectSdbViewScreenBlocState());
      } else {
        var userOrLocalId = fbIdentity.userLocalId!;
        var fsDb = this.fsDb;
        var firestore = fsDb.firestore;
        var projectsDb = this.projectsDb;
        if (projectsDb == null) {
          // No local mirror: read the entity and the access from firestore.
          _listenFirestore(fsDb, firestore, user, null);
          return;
        }
        audiAddStreamSubscription(
          projectsDb.onProject(projectId, userId: userOrLocalId).listen((
            event,
          ) {
            var dbProject = event;
            if (dbProject == null) {
              _listenFirestore(fsDb, firestore, user, dbProject);
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

  /// Listen to the firestore entity (and the user access when signed in).
  void _listenFirestore(
    TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity> fsDb,
    Firestore firestore,
    FirebaseUser? user,
    SdbUserProject? dbProject,
  ) {
    if (user != null) {
      fsSubscription = audiAddStreamSubscription(
        streamJoin2OrError(
          fsDb.fsEntityRef(projectId).onSnapshotSupport(firestore),
          fsDb
              .fsUserEntityAccessRef(userId, projectId)
              .onSnapshotSupport(firestore),
        ).listen((event) {
          var values = event.values;
          add(
            ProjectSdbViewScreenBlocState(
              project: dbProject,
              identity: identity,
              fsProject: values.$1,
              fsUserAccess: values.$2,
              dbProjectReady: true,
            ),
          );
        }),
      );
    } else {
      fsSubscription = audiAddStreamSubscription(
        fsDb.fsEntityRef(projectId).onSnapshotSupport(firestore).listen((
          event,
        ) {
          add(
            ProjectSdbViewScreenBlocState(
              project: dbProject,
              identity: identity,
              fsProject: event,
              fsUserAccess: TkCmsFsUserAccess.admin(),
              dbProjectReady: true,
            ),
          );
        }),
      );
    }
  }

  Future<void> deleteProject(SdbUserProject project) async =>
      await deleteEntityId(project.fsId);

  Future<void> leaveProject(SdbUserProject project) async =>
      await leaveEntityId(project.fsId);

  /// Delete the entity (admin access needed).
  Future<void> deleteEntityId(String entityId) async {
    await fsDb.deleteEntity(entityId, userId: userId);
  }

  /// Leave the entity (drop our own access).
  Future<void> leaveEntityId(String entityId) async {
    await fsDb.leaveEntity(entityId, userId: userId);
  }
}

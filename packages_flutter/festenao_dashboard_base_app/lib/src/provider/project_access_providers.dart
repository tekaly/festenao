/// The project access feature, as riverpod providers.
///
/// They replace `ProjectsSdbScreenBloc` and `ProjectSdbViewScreenBloc`: the
/// screens are plain consumers watching these notifiers, so the feature no
/// longer wraps a `BlocProvider` in a `Consumer` to read auth from riverpod and
/// everything else from a bloc.
///
/// The two screens work on any [TkCmsFsEntity] — a festenao project, a playelio
/// playlist, a songbookelio songbook. What varies between the apps is scoped
/// rather than passed down: a route overrides [currentEntityAccessProvider] and
/// [currentProjectsMirrorDbProvider] in a [ProviderScope], the same way the
/// project branch scopes its ids (see `dashboard_route_scope.dart`).
library;

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_dashboard_base_app/src/provider/auth_rpd.dart';
import 'package:festenao_dashboard_base_app/src/provider/festenao_user_projects.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tekartik_common_utils/stream/stream_join.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

part 'project_access_providers.g.dart';

/// The firestore entity the access screens manage.
///
/// Defaults to the festenao project; a host app overrides it in a
/// [ProviderScope] to manage its own entity (a playlist, a songbook).
final currentEntityAccessProvider =
    Provider<TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity>>(
      (ref) => globalFestenaoFirestoreDatabase.projectDb,
      name: 'currentEntityAccess',
    );

/// The local database mirroring the entities of the signed in user, or null
/// for an entity that has no local mirror.
///
/// Defaults to the festenao user projects database. An app whose entity only
/// exists in firestore (a playlist, a songbook) overrides it with null, and the
/// screens then read the entity and the access from firestore directly.
final currentProjectsMirrorDbProvider = Provider<UserProjectsSdb?>(
  (ref) => ref.watch(rpdUserProjectsDbProvider),
  name: 'currentProjectsMirrorDb',
);

/// The identity of the signed in user, null when signed out or still unknown.
@riverpod
TkCmsFbIdentity? rpdIdentity(Ref ref) =>
    ref.watch(rpdTkCmsFbIdentityBlocStateProvider).value?.identity;

/// What the projects access screen shows.
class ProjectsAccessState {
  /// The signed in identity, null when signed out.
  final TkCmsFbIdentity? identity;

  /// The projects of [identity], read from the local database.
  final List<SdbUserProject> projects;

  /// The state of the projects access screen.
  const ProjectsAccessState({this.identity, this.projects = const []});
}

/// The projects the signed in identity has access to.
///
/// The list itself comes from the local database, which is what the rest of
/// the app reads. While this provider is watched it also mirrors the firestore
/// access list into that local database, so the screen showing it is the one
/// keeping it fresh — exactly what `ProjectsSdbScreenBloc` did.
@riverpod
class RpdProjectsAccess extends _$RpdProjectsAccess {
  /// Serializes the writes to the local database, so a manual
  /// [syncUserProjects] never races the continuous mirroring.
  final _mirrorLock = Lock();

  UserProjectsSdbSynchronizer _synchronizerFor(UserProjectsSdb projectsDb) =>
      UserProjectsSdbSynchronizer(
        projectsSdb: projectsDb,
        fsProjects: globalFestenaoFirestoreDatabase.projectDb,
      );

  @override
  Stream<ProjectsAccessState> build() {
    var identity = ref.watch(rpdIdentityProvider);
    if (identity == null) {
      return Stream.value(const ProjectsAccessState());
    }
    var projectsDb = ref.watch(rpdUserProjectsDbProvider);
    // The local database is keyed by the identity local id, not by the
    // firebase user id: a service account has no user id at all.
    var identityId = identity.userOrAccountId;
    var userId = identity.userId;
    if (userId == null) {
      // Nothing to mirror from firestore, only make the local database
      // current for this identity.
      () async {
        await projectsDb.ready;
        await projectsDb.clientSetCurrentIdentityId(projectsDb.db, identityId);
      }();
    } else {
      _mirrorFirestore(projectsDb, identityId: identityId, userId: userId);
    }
    return projectsDb
        .onProjects(userId: identityId)
        .map(
          (projects) =>
              ProjectsAccessState(identity: identity, projects: projects),
        );
  }

  /// Mirrors the firestore access list of [userId] into [projectsDb] until
  /// this provider is disposed or rebuilt.
  ///
  /// Two levels: the access list says which entities are reachable, then each
  /// of them is watched for its name and details. A detail that fails to load
  /// (access revoked between the two reads) is skipped rather than failing the
  /// whole list.
  void _mirrorFirestore(
    UserProjectsSdb projectsDb, {
    required String identityId,
    required String userId,
  }) {
    var synchronizer = _synchronizerFor(projectsDb);
    var fsDb = globalFestenaoFirestoreDatabase.projectDb;
    StreamSubscription<Object?>? accessSubscription;
    StreamSubscription<Object?>? detailsSubscription;
    ref.onDispose(() {
      accessSubscription?.cancel();
      detailsSubscription?.cancel();
      synchronizer.dispose();
    });

    Future<void> apply(
      List<TkCmsFsUserAccess> userAccessList,
      List<FsProject> fsProjectList,
    ) => _mirrorLock.synchronized(
      () => synchronizer.applyUserProjects(
        userId: userId,
        identityId: identityId,
        userAccessList: userAccessList,
        fsProjectList: fsProjectList,
      ),
    );

    accessSubscription = fsDb
        .fsUserEntityAccessCollectionRef(userId)
        .onSnapshotsSupport(fsDb.firestore)
        .listen(
          (userAccessList) async {
            var entityIds = userAccessList.map((access) => access.id).toList();
            await detailsSubscription?.cancel();
            detailsSubscription = null;
            if (entityIds.isEmpty) {
              await apply(userAccessList, []);
              return;
            }
            detailsSubscription =
                streamJoinAllOrError(
                  entityIds
                      .map(
                        (id) => fsDb.fsEntityCollectionRef
                            .doc(id)
                            .onSnapshotSupport(fsDb.firestore),
                      )
                      .toList(),
                ).listen(
                  (items) {
                    apply(
                      userAccessList,
                      items
                          .where((item) => item.error == null)
                          .map((item) => item.value!)
                          .toList(),
                    );
                  },
                  onError: (Object error) {
                    if (kDebugMode) {
                      print('error getting project details: $error');
                    }
                  },
                );
          },
          onError: (Object error) {
            if (kDebugMode) {
              print('error listing the project access of $userId: $error');
            }
          },
        );
  }

  /// Rebuilds the local project list from the firestore access list, once.
  ///
  /// A no-op when signed out, or for a service account, which has no firestore
  /// access list of its own.
  Future<void> syncUserProjects() async {
    var identity = ref.read(rpdIdentityProvider);
    var userId = identity?.userId;
    if (identity == null || userId == null) {
      return;
    }
    var projectsDb = ref.read(rpdUserProjectsDbProvider);
    var synchronizer = _synchronizerFor(projectsDb);
    try {
      await _mirrorLock.synchronized(
        () => synchronizer.syncUserProjects(
          userId: userId,
          identityId: identity.userOrAccountId,
        ),
      );
    } finally {
      synchronizer.dispose();
    }
  }
}

/// What the access screen of one entity shows.
class ProjectAccessState {
  /// The signed in identity, null when signed out.
  final TkCmsFbIdentity? identity;

  /// The entity in the local mirror, null when it has none.
  final SdbUserProject? project;

  /// False until the entity has been looked up, so the screen can tell "still
  /// loading" from "no such entity".
  final bool dbProjectReady;

  /// The firestore entity, read when the local mirror has no copy of it.
  final TkCmsFsEntity? fsProject;

  /// Our own access to the entity, as firestore has it.
  final TkCmsFsUserAccess? fsUserAccess;

  /// The state of the access screen of one entity.
  ProjectAccessState({
    this.identity,
    this.project,
    this.fsProject,
    this.fsUserAccess,
    bool? dbProjectReady,
  }) : dbProjectReady = dbProjectReady ?? (project != null);
}

/// The access of the signed in user to one entity, keyed by its firestore id.
///
/// The entity is looked up in the local mirror first
/// ([currentProjectsMirrorDbProvider]) and in firestore when it has no copy of
/// it — which is always the case for an entity that has no mirror at all.
@riverpod
class RpdProjectAccess extends _$RpdProjectAccess {
  TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity> get _fsDb =>
      ref.read(currentEntityAccessProvider);

  /// The firebase user id, only for a signed in user identity.
  String? get _userId => ref.read(rpdIdentityProvider)?.userId;

  @override
  Stream<ProjectAccessState> build(String entityId) {
    var identity = ref.watch(rpdIdentityProvider);
    if (identity == null) {
      return Stream.value(ProjectAccessState());
    }
    var fsDb = ref.watch(currentEntityAccessProvider);
    var projectsDb = ref.watch(currentProjectsMirrorDbProvider);
    var user = identity.user;

    var controller = StreamController<ProjectAccessState>();
    StreamSubscription<Object?>? localSubscription;
    StreamSubscription<Object?>? fsSubscription;

    /// Reads the entity (and our access to it) from firestore, for the
    /// entities the local mirror does not have.
    void listenFirestore(SdbUserProject? dbProject) {
      fsSubscription?.cancel();
      var firestore = fsDb.firestore;
      if (user == null) {
        // Signed out: the entity is public or nothing is shown, and there is
        // no user access document to read.
        fsSubscription = fsDb
            .fsEntityRef(entityId)
            .onSnapshotSupport(firestore)
            .listen((fsProject) {
              controller.add(
                ProjectAccessState(
                  identity: identity,
                  project: dbProject,
                  fsProject: fsProject,
                  fsUserAccess: TkCmsFsUserAccess.admin(),
                  dbProjectReady: true,
                ),
              );
            });
        return;
      }
      fsSubscription =
          streamJoin2OrError(
            fsDb.fsEntityRef(entityId).onSnapshotSupport(firestore),
            fsDb
                .fsUserEntityAccessRef(user.uid, entityId)
                .onSnapshotSupport(firestore),
          ).listen((event) {
            var values = event.values;
            controller.add(
              ProjectAccessState(
                identity: identity,
                project: dbProject,
                fsProject: values.$1,
                fsUserAccess: values.$2,
                dbProjectReady: true,
              ),
            );
          });
    }

    ref.onDispose(() {
      localSubscription?.cancel();
      fsSubscription?.cancel();
      controller.close();
    });

    if (projectsDb == null) {
      listenFirestore(null);
    } else {
      localSubscription = projectsDb
          .onProject(entityId, userId: identity.userLocalId!)
          .listen((dbProject) {
            if (dbProject == null) {
              listenFirestore(dbProject);
            } else {
              controller.add(
                ProjectAccessState(
                  identity: identity,
                  project: dbProject,
                  dbProjectReady: true,
                ),
              );
            }
          });
    }
    return controller.stream;
  }

  /// Deletes the entity, admin access needed.
  Future<void> deleteEntity() async {
    await _fsDb.deleteEntity(entityId, userId: _userId!);
  }

  /// Leaves the entity: drops our own access to it, the entity itself stays.
  Future<void> leaveEntity() async {
    await _fsDb.leaveEntity(entityId, userId: _userId!);
  }
}

import 'dart:async';

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Minimal entity summary the share screen needs: a display name and what the
/// current user is allowed to grant.
///
/// Built from the local projects sdb for festenao projects, or read from
/// firestore for any other [TkCmsFsEntity] (a songbook...).
class SdbSharedEntity {
  /// Display name.
  final String? name;

  /// True when the current user is an admin of the entity.
  final bool isAdmin;

  /// True when the current user can write the entity.
  final bool isWrite;

  /// True when the current user can read the entity.
  final bool isRead;

  /// Constructor.
  SdbSharedEntity({
    this.name,
    this.isAdmin = false,
    this.isWrite = false,
    this.isRead = false,
  });

  /// From a local projects sdb record.
  SdbSharedEntity.fromUserProject(SdbUserProject project)
    : name = project.name.v,
      isAdmin = project.isAdmin,
      isWrite = project.isWrite,
      isRead = project.isRead;

  /// From the firestore entity and the current user access on it.
  SdbSharedEntity.fromFsAccess({
    required this.name,
    required TkCmsFsUserAccess? access,
  }) : isAdmin = access?.isAdmin ?? false,
       isWrite = access?.isWrite ?? false,
       isRead = access?.isRead ?? false;
}

/// State for the project share/invite screen.
class ProjectSdbShareScreenBlocState {
  /// The project being shared (for its name and access capabilities).
  final SdbSharedEntity? project;

  /// Created invite id, if any.
  final String? inviteId;

  /// The invite entity once created (and streamed).
  final TkCmsFsInviteEntity<TkCmsFsEntity>? invite;

  /// True when sharing settings can still be edited (no invite created yet).
  bool get canEditSharing => inviteId == null && project != null;

  /// True when an invite has been created and can be shown.
  bool get canViewInvite => (invite?.exists ?? false) && inviteId != null;

  ProjectSdbShareScreenBlocState({this.project, this.inviteId, this.invite});

  ProjectSdbShareScreenBlocState copyWith({
    SdbSharedEntity? project,
    String? inviteId,
    TkCmsFsInviteEntity<TkCmsFsEntity>? invite,
  }) {
    return ProjectSdbShareScreenBlocState(
      project: project ?? this.project,
      inviteId: inviteId ?? this.inviteId,
      invite: invite ?? this.invite,
    );
  }

  ProjectSdbShareScreenBlocState withProject(SdbSharedEntity? project) {
    return ProjectSdbShareScreenBlocState(
      project: project,
      inviteId: inviteId,
      invite: invite,
    );
  }

  ProjectSdbShareScreenBlocState withInvite({
    String? inviteId,
    TkCmsFsInviteEntity<TkCmsFsEntity>? invite,
  }) {
    return ProjectSdbShareScreenBlocState(
      project: project,
      inviteId: inviteId,
      invite: invite,
    );
  }
}

/// Bloc generating and tracking a project invite.
class ProjectSdbShareScreenBloc
    extends AutoDisposeStateBaseBloc<ProjectSdbShareScreenBlocState> {
  final String projectId;

  /// Local projects db, when sharing a festenao project.
  final UserProjectsSdb? projectsDb;

  /// Entity the access is managed on, defaults to the festenao project entity.
  final TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity>? entityAccess;

  TkCmsFbIdentity? _identity;
  FirebaseUser? get _user => _identity?.user;
  String get userId => _user!.uid;

  // ignore: cancel_subscriptions
  StreamSubscription? _inviteSubscription;

  ProjectSdbShareScreenBloc({
    required this.projectId,
    this.projectsDb,
    this.entityAccess,
  }) {
    add(ProjectSdbShareScreenBlocState());
    () async {
      _identity = (await globalTkCmsFbIdentityBloc.state.first).identity;
      var userOrLocalId = _identity?.userLocalId;
      if (userOrLocalId == null) {
        return;
      }
      var projectsDb = this.projectsDb;
      if (projectsDb != null) {
        audiAddStreamSubscription(
          projectsDb.onProject(projectId, userId: userOrLocalId).listen((
            project,
          ) {
            add(
              state.value.withProject(
                project == null
                    ? null
                    : SdbSharedEntity.fromUserProject(project),
              ),
            );
          }),
        );
        return;
      }
      // No local projects db (any other entity): read the name and the
      // current user access from firestore.
      var fsDb = _projectDb;
      var entity = await fsDb.fsEntityRef(projectId).get(fsDb.firestore);
      var access = await fsDb
          .fsEntityUserAccessRef(projectId, userOrLocalId)
          .get(fsDb.firestore);
      if (disposed) {
        return;
      }
      add(
        state.value.withProject(
          SdbSharedEntity.fromFsAccess(
            name: entity.name.v,
            access: access.exists ? access : null,
          ),
        ),
      );
    }();
  }

  /// Firestore entity database the invites are created on.
  TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity> get _projectDb =>
      entityAccess ?? globalFestenaoFirestoreDatabase.projectDb;

  /// Create an invite with the given access and start tracking it.
  Future<String> createInvite({
    required bool admin,
    required bool write,
    required bool read,
  }) async {
    var fsDb = _projectDb;
    var fsProject = await fsDb.fsEntityRef(projectId).get(fsDb.firestore);
    var userAccess = TkCmsCvUserAccess()
      ..read.v = read
      ..write.v = write
      ..admin.v = admin;
    var inviteId = await fsDb.createInviteEntity(
      userId: userId,
      entityId: projectId,
      userAccess: userAccess,
      entity: fsProject,
    );

    audiDispose(_inviteSubscription);
    _inviteSubscription = audiAddStreamSubscription(
      fsDb.onInviteEntity(inviteId, projectId).listen((invite) {
        if (!invite.exists && state.value.inviteId == inviteId) {
          add(state.value.withInvite(inviteId: null, invite: null));
          return;
        }
        add(state.value.copyWith(inviteId: inviteId, invite: invite));
      }),
    );
    return inviteId;
  }

  /// Delete the invite with the given id.
  Future<void> deleteInvite(String inviteId) async {
    await _projectDb.deleteInviteEntity(
      inviteId: inviteId,
      entityId: projectId,
    );
    add(state.value.withInvite(inviteId: null, invite: null));
  }
}

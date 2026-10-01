import 'dart:async';

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/festenao_api.dart';
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

  /// The email invites sent on the entity, most recent first, with what
  /// happened to them; null until loaded (or when they are not supported,
  /// see [ProjectSdbShareScreenBloc.emailInvitesSupported]).
  final List<TkCmsCvEmailInvite>? emailInvites;

  /// The error of the last email invites load, if any.
  final Object? emailInvitesError;

  /// True when sharing settings can still be edited (no invite created yet).
  bool get canEditSharing => inviteId == null && project != null;

  /// True when an invite has been created and can be shown.
  bool get canViewInvite => (invite?.exists ?? false) && inviteId != null;

  ProjectSdbShareScreenBlocState({
    this.project,
    this.inviteId,
    this.invite,
    this.emailInvites,
    this.emailInvitesError,
  });

  ProjectSdbShareScreenBlocState copyWith({
    SdbSharedEntity? project,
    String? inviteId,
    TkCmsFsInviteEntity<TkCmsFsEntity>? invite,
    List<TkCmsCvEmailInvite>? emailInvites,
  }) {
    return ProjectSdbShareScreenBlocState(
      project: project ?? this.project,
      inviteId: inviteId ?? this.inviteId,
      invite: invite ?? this.invite,
      emailInvites: emailInvites ?? this.emailInvites,
      emailInvitesError: emailInvitesError,
    );
  }

  ProjectSdbShareScreenBlocState withProject(SdbSharedEntity? project) {
    return ProjectSdbShareScreenBlocState(
      project: project,
      inviteId: inviteId,
      invite: invite,
      emailInvites: emailInvites,
      emailInvitesError: emailInvitesError,
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
      emailInvites: emailInvites,
      emailInvitesError: emailInvitesError,
    );
  }

  /// The email invites after a load, or its error.
  ProjectSdbShareScreenBlocState withEmailInvites(
    List<TkCmsCvEmailInvite>? emailInvites, {
    Object? error,
  }) {
    return ProjectSdbShareScreenBlocState(
      project: project,
      inviteId: inviteId,
      invite: invite,
      emailInvites: emailInvites,
      emailInvitesError: error,
    );
  }
}

/// Bloc generating and tracking a project invite (a link), and managing the
/// email invites of the entity (addressed invites, through the secured api).
class ProjectSdbShareScreenBloc
    extends AutoDisposeStateBaseBloc<ProjectSdbShareScreenBlocState> {
  final String projectId;

  /// Local projects db, when sharing a festenao project.
  final UserProjectsSdb? projectsDb;

  /// Entity the access is managed on, defaults to the festenao project entity.
  final TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity>? entityAccess;

  /// The secured api the email invites go through: the festenao one
  /// (`globalFestenaoApiServiceOrNull`) by default, the app's own otherwise
  /// (a playlist invite goes through the playelio api). Without any, the
  /// email invites are not offered (standalone), see [emailInvitesSupported].
  final TkCmsApiServiceBaseV2? apiService;

  TkCmsFbIdentity? _identity;
  FirebaseUser? get _user => _identity?.user;
  String get userId => _user!.uid;

  // ignore: cancel_subscriptions
  StreamSubscription? _inviteSubscription;
  var _emailInvitesLoaded = false;

  ProjectSdbShareScreenBloc({
    required this.projectId,
    this.projectsDb,
    this.entityAccess,
    this.apiService,
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
            var sharedProject = project == null
                ? null
                : SdbSharedEntity.fromUserProject(project);
            add(state.value.withProject(sharedProject));
            _loadEmailInvitesOnce(sharedProject);
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
      var sharedProject = SdbSharedEntity.fromFsAccess(
        name: entity.name.v,
        access: access.exists ? access : null,
      );
      add(state.value.withProject(sharedProject));
      _loadEmailInvitesOnce(sharedProject);
    }();
  }

  /// Firestore entity database the invites are created on.
  TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity> get _projectDb =>
      entityAccess ?? globalFestenaoFirestoreDatabase.projectDb;

  TkCmsApiServiceBaseV2? get _apiService =>
      apiService ?? globalFestenaoApiServiceOrNull;

  /// True when the email invites can be managed here: they are admin only
  /// data, nothing is read or written without the secured api
  /// ([apiService]).
  bool get emailInvitesSupported => _apiService != null;

  FestenaoApiFsEntityClient<TkCmsFsEntity> get _apiClient =>
      FestenaoApiFsEntityClient<TkCmsFsEntity>(
        apiService: _apiService!,
        entityAccess: _projectDb,
      );

  /// Load the email invites once, when the project is known and the user is
  /// an admin of it (only an admin may list them).
  void _loadEmailInvitesOnce(SdbSharedEntity? project) {
    if (_emailInvitesLoaded ||
        project == null ||
        !project.isAdmin ||
        !emailInvitesSupported) {
      return;
    }
    _emailInvitesLoaded = true;
    () async {
      try {
        await refreshEmailInvites();
      } catch (e) {
        if (!disposed) {
          add(state.value.withEmailInvites(null, error: e));
        }
      }
    }();
  }

  /// Refresh the email invites (the server reads them, nothing streams).
  Future<void> refreshEmailInvites() async {
    if (!emailInvitesSupported) {
      return;
    }
    var invites = await _apiClient.listEntityEmailInvites(entityId: projectId);
    if (disposed) {
      return;
    }
    add(state.value.withEmailInvites(invites));
  }

  /// Send an addressed email invite with the given access, return its id
  /// and refresh the list. Inviting a pending email again updates its
  /// invite.
  Future<String> createEmailInvite({
    required String email,
    required bool admin,
    required bool write,
    required bool read,
  }) async {
    var inviteId = await _apiClient.createEntityEmailInvite(
      entityId: projectId,
      email: email,
      fsUserAccess: TkCmsFsUserAccess()
        ..read.v = read
        ..write.v = write
        ..admin.v = admin,
    );
    await refreshEmailInvites();
    return inviteId;
  }

  /// Revoke (delete) an email invite, whatever its status, and refresh the
  /// list.
  Future<void> deleteEmailInvite(String inviteId) async {
    await _apiClient.deleteEntityEmailInvite(
      entityId: projectId,
      inviteId: inviteId,
    );
    await refreshEmailInvites();
  }

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

import 'dart:async';

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// State for the project share/invite screen.
class ProjectSdbShareScreenBlocState {
  /// The project being shared (for its name and access capabilities).
  final SdbUserProject? project;

  /// Created invite id, if any.
  final String? inviteId;

  /// The invite entity once created (and streamed).
  final TkCmsFsInviteEntity<FsProject>? invite;

  /// True when sharing settings can still be edited (no invite created yet).
  bool get canEditSharing => inviteId == null && project != null;

  /// True when an invite has been created and can be shown.
  bool get canViewInvite => (invite?.exists ?? false) && inviteId != null;

  ProjectSdbShareScreenBlocState({this.project, this.inviteId, this.invite});

  ProjectSdbShareScreenBlocState copyWith({
    SdbUserProject? project,
    String? inviteId,
    TkCmsFsInviteEntity<FsProject>? invite,
  }) {
    return ProjectSdbShareScreenBlocState(
      project: project ?? this.project,
      inviteId: inviteId ?? this.inviteId,
      invite: invite ?? this.invite,
    );
  }

  ProjectSdbShareScreenBlocState withProject(SdbUserProject? project) {
    return ProjectSdbShareScreenBlocState(
      project: project,
      inviteId: inviteId,
      invite: invite,
    );
  }

  ProjectSdbShareScreenBlocState withInvite({
    String? inviteId,
    TkCmsFsInviteEntity<FsProject>? invite,
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
  final UserProjectsSdb projectsDb;

  TkCmsFbIdentity? _identity;
  FirebaseUser? get _user => _identity?.user;
  String get userId => _user!.uid;

  // ignore: cancel_subscriptions
  StreamSubscription? _inviteSubscription;

  ProjectSdbShareScreenBloc({
    required this.projectId,
    required this.projectsDb,
  }) {
    add(ProjectSdbShareScreenBlocState());
    () async {
      _identity = (await globalTkCmsFbIdentityBloc.state.first).identity;
      var userOrLocalId = _identity?.userLocalId;
      if (userOrLocalId == null) {
        return;
      }
      audiAddStreamSubscription(
        projectsDb.onProject(projectId, userId: userOrLocalId).listen((
          project,
        ) {
          add(state.value.withProject(project));
        }),
      );
    }();
  }

  /// Firestore project entity database.
  TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> get _projectDb =>
      globalFestenaoFirestoreDatabase.projectDb;

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

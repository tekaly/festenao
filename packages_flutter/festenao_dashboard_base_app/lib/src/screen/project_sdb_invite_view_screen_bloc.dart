import 'dart:async';

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// State for the project invite view screen.
class ProjectSdbInviteViewScreenBlocState {
  /// Current firebase user (null when not signed in).
  final FirebaseUser? user;

  /// The invite entity (check `exists`; gone once accepted/deleted).
  final TkCmsFsInviteEntity<FsProject>? invite;

  /// True once the invite has been accepted.
  final bool accepted;

  /// Current user project record if they are already part of it.
  final SdbUserProject? userProject;

  ProjectSdbInviteViewScreenBlocState({
    this.user,
    this.invite,
    this.accepted = false,
    this.userProject,
  });
}

/// Bloc tracking a single project invite, with accept / delete actions.
class ProjectSdbInviteViewScreenBloc
    extends AutoDisposeStateBaseBloc<ProjectSdbInviteViewScreenBlocState> {
  final String projectId;
  final String inviteId;

  TkCmsFbIdentity? _identity;
  FirebaseUser? get _user => _identity?.user;
  String get userId => _user!.uid;

  // ignore: cancel_subscriptions
  StreamSubscription? _inviteSubscription;
  // ignore: cancel_subscriptions
  StreamSubscription? _userProjectSubscription;

  ProjectSdbInviteViewScreenBloc({
    required this.projectId,
    required this.inviteId,
  }) {
    () async {
      audiAddStreamSubscription(
        globalTkCmsFbIdentityBloc.state.listen((identityState) {
          _identity = identityState.identity;
          var user = _identity?.user;
          audiDispose(_inviteSubscription);
          audiDispose(_userProjectSubscription);
          if (user == null) {
            add(ProjectSdbInviteViewScreenBlocState(user: null));
            return;
          }
          _inviteSubscription = audiAddStreamSubscription(
            _projectDb.onInviteEntity(inviteId, projectId).listen((invite) {
              var currentState = state.valueOrNull;
              add(
                ProjectSdbInviteViewScreenBlocState(
                  user: user,
                  invite: invite,
                  accepted: currentState?.accepted ?? false,
                  userProject: currentState?.userProject,
                ),
              );
            }),
          );
          _userProjectSubscription = audiAddStreamSubscription(
            globalProjectsSdb.onProject(projectId, userId: user.uid).listen((
              userProject,
            ) {
              var currentState = state.valueOrNull;
              add(
                ProjectSdbInviteViewScreenBlocState(
                  user: user,
                  invite: currentState?.invite,
                  accepted: currentState?.accepted ?? false,
                  userProject: userProject,
                ),
              );
            }),
          );
        }),
      );
    }();
  }

  /// Firestore project entity database.
  TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> get _projectDb =>
      globalFestenaoFirestoreDatabase.projectDb;

  /// Accept the invite, granting access to the current user.
  Future<void> acceptInvite() async {
    await _projectDb.acceptInviteEntity(
      userId: userId,
      inviteId: inviteId,
      entityId: projectId,
    );
    add(
      ProjectSdbInviteViewScreenBlocState(
        user: _user,
        invite: state.valueOrNull?.invite,
        accepted: true,
        userProject: state.valueOrNull?.userProject,
      ),
    );
  }

  /// Delete the invite.
  Future<void> deleteInvite() async {
    await _projectDb.deleteInviteEntity(
      inviteId: inviteId,
      entityId: projectId,
    );
  }

  /// Update the invite's user access role.
  Future<void> updateInviteAccess({
    required bool admin,
    required bool write,
    required bool read,
  }) async {
    var inviteEntityRef = _projectDb.fsInviteEntityRef(inviteId, projectId);
    var invite = await inviteEntityRef.get(_projectDb.firestore);
    if (invite.exists) {
      var access = invite.userAccess.v ??= TkCmsCvUserAccess();
      access.admin.v = admin;
      access.write.v = write;
      access.read.v = read;
      await inviteEntityRef.set(_projectDb.firestore, invite);
    }
  }
}

import 'dart:async';

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
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

  ProjectSdbInviteViewScreenBlocState({
    this.user,
    this.invite,
    this.accepted = false,
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
          if (user == null) {
            add(ProjectSdbInviteViewScreenBlocState(user: null));
            return;
          }
          _inviteSubscription = audiAddStreamSubscription(
            _projectDb.onInviteEntity(inviteId, projectId).listen((invite) {
              add(
                ProjectSdbInviteViewScreenBlocState(
                  user: user,
                  invite: invite,
                  accepted: state.valueOrNull?.accepted ?? false,
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
}

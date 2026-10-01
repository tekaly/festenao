/// The pending email invites of the signed in user (festenao
/// `doc/invite_by_email.md`): checked through the api when the identity
/// changes (the app start, each sign in and out) and on demand, accepted or
/// declined from the `PendingEmailInvitesView`.
///
/// The invites are admin only data: nothing is read from firestore here, the
/// `check-email-invites` command resolves the caller's verified email server
/// side and lists the pending invites addressed to it.
library;

import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/api/festenao_api_fs_entity_client.dart';
import 'package:festenao_dashboard_base_app/src/provider/project_access_providers.dart';
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tkcms_common/tkcms_api.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// The api service the email invites of the user go through (check, accept,
/// decline), null when the app has none: no invite is then ever shown.
///
/// Defaults to the global festenao api service; an app overrides it with its
/// own, the same way it overrides [currentEntityAccessProvider] with its
/// entity (the invites of a playlist come through the playelio api).
final emailInviteApiServiceProvider = Provider<TkCmsApiServiceBaseV2?>(
  (ref) => globalFestenaoApiServiceOrNull,
  name: 'emailInviteApiService',
);

/// The pending email invites addressed to the signed in user.
class PendingEmailInvitesState {
  /// The signed in identity, null when signed out.
  final TkCmsFbIdentity? identity;

  /// The user email (normalized), null when the account has none or when
  /// signed out.
  final String? email;

  /// Whether the user email is verified: no invite is listed, and none can be
  /// accepted, until it is.
  final bool emailVerified;

  /// The pending invites, most recent first.
  final List<TkCmsCvEmailInvite> invites;

  /// False when the app has no api service for the email invites.
  final bool supported;

  /// The pending email invites state.
  const PendingEmailInvitesState({
    this.identity,
    this.email,
    this.emailVerified = false,
    this.invites = const [],
    this.supported = true,
  });

  /// True when there is nothing to show.
  bool get isEmpty => invites.isEmpty;

  /// The state without [invite] (accepted or declined).
  PendingEmailInvitesState without(TkCmsCvEmailInvite invite) =>
      PendingEmailInvitesState(
        identity: identity,
        email: email,
        emailVerified: emailVerified,
        invites: invites
            .where((item) => item.inviteId.v != invite.inviteId.v)
            .toList(),
        supported: supported,
      );

  @override
  String toString() =>
      'PendingEmailInvitesState(${identity?.userLocalId}, $email, '
      'verified: $emailVerified, ${invites.length} invites)';
}

/// The pending email invites of the signed in user, checked again on every
/// identity change (the app start, each sign in and out) and on [refresh].
class RpdPendingEmailInvites extends AsyncNotifier<PendingEmailInvitesState> {
  /// The api client of the current entity type, null without an api service.
  FestenaoApiFsEntityClient<TkCmsFsEntity>? _clientOrNull(
    TkCmsApiServiceBaseV2? apiService,
  ) {
    if (apiService == null) {
      return null;
    }
    return FestenaoApiFsEntityClient<TkCmsFsEntity>(
      apiService: apiService,
      entityAccess: ref.read(currentEntityAccessProvider),
    );
  }

  FestenaoApiFsEntityClient<TkCmsFsEntity> get _client {
    var client = _clientOrNull(ref.read(emailInviteApiServiceProvider));
    if (client == null) {
      throw StateError('No api service for the email invites');
    }
    return client;
  }

  @override
  Future<PendingEmailInvitesState> build() async {
    // Rebuilt on every identity change: the app start, each sign in and out.
    var identity = ref.watch(rpdIdentityProvider);
    var apiService = ref.watch(emailInviteApiServiceProvider);
    var client = _clientOrNull(apiService);
    if (identity?.userId == null || client == null) {
      return PendingEmailInvitesState(
        identity: identity,
        supported: client != null,
      );
    }
    var result = await client.checkEmailInvites();
    return PendingEmailInvitesState(
      identity: identity,
      email: result.email.v,
      emailVerified: result.emailVerified.v ?? false,
      invites: result.invites.v ?? const [],
    );
  }

  /// Checks the pending invites again.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Accepts [invite]: the user gets its access on the entity.
  Future<void> accept(TkCmsCvEmailInvite invite) async {
    await _client.acceptEntityEmailInvite(
      entityId: invite.entityId.v!,
      inviteId: invite.inviteId.v!,
    );
    await refresh();
  }

  /// Declines [invite]: no access, it cannot be accepted any more.
  Future<void> discard(TkCmsCvEmailInvite invite) async {
    await _client.discardEntityEmailInvite(
      entityId: invite.entityId.v!,
      inviteId: invite.inviteId.v!,
    );
    await refresh();
  }
}

/// The pending email invites of the signed in user, see
/// [RpdPendingEmailInvites].
final rpdPendingEmailInvitesProvider =
    AsyncNotifierProvider<RpdPendingEmailInvites, PendingEmailInvitesState>(
      RpdPendingEmailInvites.new,
      name: 'rpdPendingEmailInvites',
    );

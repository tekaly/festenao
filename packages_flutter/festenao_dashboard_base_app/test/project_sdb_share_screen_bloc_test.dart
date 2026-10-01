import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:festenao_dashboard_base_app/screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// The share screen bloc email invites, through the api of the in memory
/// festenao server (the context of the festenao_common api tests).
void main() {
  late FestenaoTestServerContext context;

  setUpAll(() async {
    context = await initFestenaoTestServerContextAllMemory();
    // What the apps do at start: the blocs read the identity from here. It
    // only sees the sign-ins that happen after it: sign the owner (already
    // signed in by the context) out and in again.
    var auth = context.clientContext.firebaseAuth!;
    globalTkCmsFbIdentityBloc = TkCmsFbIdentityBloc(auth: auth);
    var credentials = context.clientContext.credentials!;
    await auth.signOut();
    await auth.signInOrUpWithEmailAndPassword(
      email: credentials.email,
      password: credentials.password,
    );
    await globalTkCmsFbIdentityBloc.state.firstWhere(
      (state) => state.identity != null,
    );
  });
  tearDownAll(() async {
    await context.close();
  });

  test('email invites need an api service', () async {
    expect(globalFestenaoApiServiceOrNull, isNull);
    var bloc = ProjectSdbShareScreenBloc(
      projectId: 'no_api_project',
      entityAccess: context.fsDatabase.projectDb,
    );
    expect(bloc.emailInvitesSupported, isFalse);
    bloc.dispose();
  });

  test('email invites: send, list, revoke', () async {
    var entityId = (await context.projectApiClient.createEntity(
      entity: FsProject()..name.v = 'Share test',
    )).id;
    var bloc = ProjectSdbShareScreenBloc(
      projectId: entityId,
      entityAccess: context.fsDatabase.projectDb,
      apiService: context.apiService,
    );
    expect(bloc.emailInvitesSupported, isTrue);
    var state = await bloc.state.firstWhere((s) => s.project != null);
    expect(state.project!.name, 'Share test');
    expect(state.project!.isAdmin, isTrue);
    // Loaded once the admin knows the project: none yet.
    state = await bloc.state.firstWhere((s) => s.emailInvites != null);
    expect(state.emailInvites, isEmpty);
    expect(state.emailInvitesError, isNull);

    // Deliberately not normalized.
    var inviteId = await bloc.createEmailInvite(
      email: ' Invited@Test.Local ',
      admin: false,
      write: true,
      read: true,
    );
    var invites = bloc.state.value.emailInvites!;
    expect(invites.map((e) => e.inviteId.v), [inviteId]);
    var invite = invites.single;
    expect(invite.email.v, 'invited@test.local');
    expect(invite.entityId.v, entityId);
    expect(invite.status.v, tkCmsEmailInviteStatusPending);
    expect(invite.isRead, isTrue);
    expect(invite.isWrite, isTrue);
    expect(invite.isAdmin, isFalse);

    // The same email again updates the pending invite.
    var inviteId2 = await bloc.createEmailInvite(
      email: 'invited@test.local',
      admin: true,
      write: true,
      read: true,
    );
    expect(inviteId2, inviteId);
    invites = bloc.state.value.emailInvites!;
    expect(invites.length, 1);
    expect(invites.single.isAdmin, isTrue);

    await bloc.deleteEmailInvite(inviteId);
    expect(bloc.state.value.emailInvites, isEmpty);
    bloc.dispose();

    await context.projectApiClient.deleteEntity(entityId: entityId);
    await context.projectApiClient.purgeEntity(entityId: entityId);
  });
}

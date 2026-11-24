import 'package:festenao_common/api/festenao_api_fs_entity_client.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/server/festeano_server_entity_handler.dart';
import 'package:festenao_common/test/festenao_email_invite_test_runner.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// The pending email invites provider, through the api of the in memory
/// festenao server: checked again on each sign in, accept and decline.
void main() {
  late FestenaoTestServerContext context;
  late FirebaseAuth auth;

  Future<void> signInOwner() async {
    var credentials = context.clientContext.credentials!;
    await auth.signOut();
    await auth.signInOrUpWithEmailAndPassword(
      email: credentials.email,
      password: credentials.password,
    );
  }

  setUpAll(() async {
    context = await initFestenaoTestServerContextAllMemory();
    auth = context.clientContext.firebaseAuth!;
    // What the apps do at start: the providers read the identity from here.
    // It only sees the sign-ins that happen after it.
    globalTkCmsFbIdentityBloc = TkCmsFbIdentityBloc(auth: auth);
    await signInOwner();
    await globalTkCmsFbIdentityBloc.state.firstWhere(
      (state) => state.identity != null,
    );
  });
  tearDownAll(() async {
    await context.close();
  });

  ProviderContainer newContainer({
    bool withApi = true,
    FestenaoAppEntity? appEntity,
  }) {
    var container = ProviderContainer(
      overrides: [
        emailInviteApiServiceProvider.overrideWithValue(
          withApi ? context.apiService : null,
        ),
        currentEntityAccessProvider.overrideWithValue(
          context.fsDatabase.projectDb,
        ),
        festenaoAppEntityProvider.overrideWithValue(appEntity),
      ],
    );
    addTearDown(container.dispose);
    // Kept alive the way a watching screen would.
    addTearDown(
      container.listen(rpdPendingEmailInvitesProvider, (_, _) {}).close,
    );
    return container;
  }

  /// The state once [test] accepts it: the identity reaches the provider
  /// through a stream, after a first build without it, and a change of it
  /// (a sign in, a sign out) the same way.
  Future<PendingEmailInvitesState> waitState(
    ProviderContainer container,
    bool Function(PendingEmailInvitesState state) test,
  ) async {
    while (true) {
      var state = await container.read(rpdPendingEmailInvitesProvider.future);
      if (test(state)) {
        return state;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('signed in without an invite', () async {
    var container = newContainer();
    var state = await waitState(container, (state) => state.identity != null);
    expect(state.supported, isTrue);
    expect(state.invites, isEmpty);
    // The owner account of the memory context has no verified email.
    expect(state.emailVerified, isFalse);
  });

  test('without an api service nothing is checked', () async {
    var container = newContainer(withApi: false);
    var state = await waitState(container, (state) => state.identity != null);
    expect(state.supported, isFalse);
    expect(state.invites, isEmpty);
  });

  test('the invitee signs in, accepts one, declines the other', () async {
    var invitedEmail = 'pending-invitee@festenao-test.local';
    var client = context.projectApiClient;
    // The owner creates two entities and invites the same address on both.
    var entityId1 = (await client.createEntity(
      entity: FsProject()..name.v = 'Pending one',
    )).id;
    await client.createEntityEmailInvite(
      entityId: entityId1,
      email: invitedEmail,
      fsUserAccess: TkCmsFsUserAccess()..write.v = true,
    );
    var entityId2 = (await client.createEntity(
      entity: FsProject()..name.v = 'Pending two',
    )).id;
    await client.createEntityEmailInvite(
      entityId: entityId2,
      email: invitedEmail,
      fsUserAccess: TkCmsFsUserAccess()..read.v = true,
    );

    var container = newContainer();
    var state = await waitState(container, (state) => state.identity != null);
    expect(state.invites, isEmpty, reason: 'the owner has no invite');

    // The invitee signs in (verified): the identity change checks again.
    var invitedUserId = await festenaoLocalAuthSignInVerified(
      context,
      invitedEmail,
    );
    state = await waitState(
      container,
      (state) => state.identity?.userId == invitedUserId,
    );
    expect(state.email, invitedEmail);
    expect(state.emailVerified, isTrue);
    expect(state.invites.map((e) => e.entityId.v).toSet(), {
      entityId1,
      entityId2,
    });
    expect(
      state.invites.firstWhere((e) => e.entityId.v == entityId1).entityName.v,
      'Pending one',
    );

    var notifier = container.read(rpdPendingEmailInvitesProvider.notifier);
    await notifier.accept(
      state.invites.firstWhere((e) => e.entityId.v == entityId1),
    );
    state = await container.read(rpdPendingEmailInvitesProvider.future);
    expect(state.invites.map((e) => e.entityId.v), [entityId2]);
    // The in memory firestore has no rules: the access is read directly.
    var firestore = context.clientContext.firestore!;
    var access = await context.fsDatabase.projectDb
        .fsEntityUserAccessRef(entityId1, invitedUserId)
        .get(firestore);
    expect(access.exists, isTrue);
    expect(access.isWrite, isTrue);
    expect(access.isAdmin, isFalse);

    await notifier.discard(state.invites.single);
    state = await container.read(rpdPendingEmailInvitesProvider.future);
    expect(state.invites, isEmpty);
    expect(
      (await context.fsDatabase.projectDb
              .fsEntityUserAccessRef(entityId2, invitedUserId)
              .get(firestore))
          .exists,
      isFalse,
    );

    // Signed out: nothing.
    await auth.signOut();
    state = await waitState(container, (state) => state.identity == null);
    expect(state.invites, isEmpty);
    expect(state.email, isNull);

    await signInOwner();
    for (var entityId in [entityId1, entityId2]) {
      await client.deleteEntity(entityId: entityId);
      await client.purgeEntity(entityId: entityId);
    }
  });
  test('the invites of the app itself, this app only', () async {
    var invitedEmail = 'app-invitee@festenao-test.local';
    var fsDatabase = context.fsDatabase;
    var firestore = context.clientContext.firestore!;
    var appDb = fsDatabase.appDb;
    // The server serves the app entity commands (a festenaoprv server does).
    var server = context.serverApp!;
    var appHandler = FestenaoEntityHandler<TkCmsFsApp>(
      app: server,
      entityAccess: appDb,
    );
    server.moduleApiHandlers.add(appHandler);
    addTearDown(() => server.moduleApiHandlers.remove(appHandler));

    // Two apps of the project, the owner admin of both (no rules in memory).
    await signInOwner();
    var ownerId = auth.currentUser!.uid;
    const otherApp = 'other-app';
    for (var app in [fsDatabase.app, otherApp]) {
      await appDb.fsEntityRef(app).set(firestore, TkCmsFsApp()..name.v = app);
      await appDb
          .fsEntityUserAccessRef(app, ownerId)
          .set(firestore, TkCmsFsUserAccess()..grantAdminAccess());
    }
    var appClient = FestenaoApiFsEntityClient<TkCmsFsApp>(
      apiService: context.apiService,
      entityAccess: appDb,
    );
    var inviteId = await appClient.createEntityEmailInvite(
      entityId: fsDatabase.app,
      email: invitedEmail,
      fsUserAccess: TkCmsFsUserAccess()..grantAdminAccess(),
    );
    await appClient.createEntityEmailInvite(
      entityId: otherApp,
      email: invitedEmail,
      fsUserAccess: TkCmsFsUserAccess()..grantAdminAccess(),
    );

    var container = newContainer(
      appEntity: FestenaoAppEntity(
        entityAccess: appDb,
        entityId: fsDatabase.app,
      ),
    );
    var invitedUserId = await festenaoLocalAuthSignInVerified(
      context,
      invitedEmail,
    );
    var state = await waitState(
      container,
      (state) => state.identity?.userId == invitedUserId,
    );
    // This app's invite only.
    expect(state.invites.map((e) => e.inviteId.v), [inviteId]);
    expect(state.invites.single.isAdmin, isTrue);

    // Accepted through the app entity: an app admin now.
    await container
        .read(rpdPendingEmailInvitesProvider.notifier)
        .accept(state.invites.single);
    state = await container.read(rpdPendingEmailInvitesProvider.future);
    expect(state.invites, isEmpty);
    var access = await appDb
        .fsEntityUserAccessRef(fsDatabase.app, invitedUserId)
        .get(firestore);
    expect(access.isAdmin, isTrue);
    // Followed live by the app access of the user.
    addTearDown(container.listen(rpdAppUserAccessProvider, (_, _) {}).close);
    TkCmsFsUserAccess? appAccess;
    for (var i = 0; i < 100 && !(appAccess?.isAdmin ?? false); i++) {
      appAccess = await container.read(rpdAppUserAccessProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(appAccess!.isAdmin, isTrue);

    // Without the app entity, its invites are not checked.
    await signInOwner();
    inviteId = await appClient.createEntityEmailInvite(
      entityId: fsDatabase.app,
      email: 'other-invitee@festenao-test.local',
      fsUserAccess: TkCmsFsUserAccess()..grantAdminAccess(),
    );
    var plain = newContainer();
    var otherUserId = await festenaoLocalAuthSignInVerified(
      context,
      'other-invitee@festenao-test.local',
    );
    state = await waitState(
      plain,
      (state) => state.identity?.userId == otherUserId,
    );
    expect(state.invites, isEmpty);
    await signInOwner();
  });
}

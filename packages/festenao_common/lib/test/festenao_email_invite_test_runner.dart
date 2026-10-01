import 'package:dev_test/test.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/api/festenao_api_fs_entity_client.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/src/data/firestore/firestore_doc_api.dart';
import 'package:tkcms_common/tkcms_api.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

import 'festenao_invite_email_test_runner.dart' show festenaoInviteTestPassword;
import 'festenao_test_server_test_runner.dart';

/// Signs in a user whose email is verified, creating it first when needed,
/// on a local auth that implements the admin api (the in memory server);
/// returns its id.
///
/// The emulator context has no such hook yet: the tests that need a verified
/// email are skipped there.
Future<String> festenaoLocalAuthSignInVerified(
  FestenaoTestServerContext context,
  String email,
) async {
  var auth = context.clientContext.firebaseAuth!;
  await auth.signOut();
  if (await auth.getUserByEmail(email) == null) {
    await (auth as FirebaseAuthAdmin).createUser(
      FirebaseAuthCreateUserRequest(
        email: email,
        password: festenaoInviteTestPassword,
        emailVerified: true,
      ),
    );
  }
  var credential = await auth.signInWithEmailAndPassword(
    email: email,
    password: festenaoInviteTestPassword,
  );
  return credential.user.uid;
}

/// Test group for the addressed email invite api (festenao
/// `doc/invite_by_email.md`): create, list and delete by an entity admin or
/// an app admin, check, accept and discard by the invitee.
///
/// [signInVerified] signs in (creating it if needed) a user whose email is
/// verified, see [festenaoLocalAuthSignInVerified]; without it the invitee
/// side tests are skipped. [closeContext] is false when the context is shared
/// with other groups that run after this one.
void testFestenaoEmailInviteGroup(
  Future<FestenaoTestServerContext> Function() initAllContext, {
  Future<String> Function(FestenaoTestServerContext context, String email)?
  signInVerified,
  bool closeContext = true,
}) {
  late FestenaoTestServerContext context;
  late FestenaoApiService apiService;
  late FestenaoFirestoreDatabase fsDatabase;
  late FirebaseAuth auth;
  late FestenaoApiFsEntityClient<FsProject> client;
  var skipVerified = signInVerified == null
      ? 'needs a verified email (no signInVerified hook)'
      : null;

  setUpAll(() async {
    context = await initAllContext();
    apiService = context.apiService;
    fsDatabase = context.fsDatabase;
    auth = context.clientContext.firebaseAuth!;
    client = context.projectApiClient;
  });
  tearDownAll(() async {
    if (closeContext) {
      await context.close();
    }
  });

  /// Sign in as the owner (the context credentials user) and return its id.
  Future<String> signInOwner() async {
    var credentials = context.clientContext.credentials;
    if (credentials == null) {
      throw StateError('Auth and credentials are required for this test');
    }
    var userCredential = await auth.signInOrUpWithEmailAndPassword(
      email: credentials.email,
      password: credentials.password,
    );
    return userCredential.user.uid;
  }

  /// Sign in (or up) a user whose email is not verified, return its id.
  Future<String> signInUnverified(String email) async {
    await auth.signOut();
    var userCredential = await auth.signInOrUpWithEmailAndPassword(
      email: email,
      password: festenaoInviteTestPassword,
    );
    return userCredential.user.uid;
  }

  /// Create an entity with an admin owner, returns the owner user id.
  ///
  /// Done through the doc api (admin side) to not depend on the entity create
  /// api here.
  Future<String> setUpEntity(String entityId) async {
    var docApiService = apiService.docApiService;
    var userId = await signInOwner();
    await docApiService.cvSetDoc(
      fsDatabase.projectDb.fsEntityUserAccessRef(entityId, userId).cv()
        ..grantAdminAccess(),
    );
    await docApiService.cvSetDoc(
      fsDatabase.projectDb.fsEntityRef(entityId).cv()..name.v = entityId,
    );
    return userId;
  }

  /// Delete everything created for [entityId], as the owner.
  Future<void> tearDownEntity(
    String entityId,
    List<String> userIds, {
    List<String> inviteIds = const [],
  }) async {
    await signInOwner();
    var docApiService = apiService.docApiService;
    await docApiService.cvDeleteDoc(fsDatabase.projectDb.fsEntityRef(entityId));
    for (var userId in userIds) {
      await docApiService.cvDeleteDoc(
        fsDatabase.projectDb.fsEntityUserAccessRef(entityId, userId),
      );
      await docApiService.cvDeleteDoc(
        fsDatabase.projectDb.fsUserEntityAccessRef(userId, entityId),
      );
    }
    for (var inviteId in inviteIds) {
      await docApiService.cvDeleteDoc(
        fsDatabase.projectDb.fsEmailInviteRef(inviteId),
      );
    }
  }

  /// The invite document, admin only data read through the doc api.
  Future<TkCmsFsEmailInvite<FsProject>?> getFsInvite(String inviteId) =>
      apiService.docApiService.cvGetDoc<TkCmsFsEmailInvite<FsProject>>(
        fsDatabase.projectDb.fsEmailInviteRef(inviteId),
      );

  test('create, list, delete by an entity admin', () async {
    var entityId = 'test_email_invite_admin_entity';
    var ownerUserId = await setUpEntity(entityId);

    // Deliberately not normalized.
    var inviteId = await client.createEntityEmailInvite(
      entityId: entityId,
      email: ' Invited@Test.Local ',
      fsUserAccess: TkCmsFsUserAccess()..read.v = true,
    );
    var invites = await client.listEntityEmailInvites(entityId: entityId);
    expect(invites.map((e) => e.inviteId.v), [inviteId]);
    var invite = invites.first;
    expect(invite.email.v, 'invited@test.local');
    expect(invite.status.v, tkCmsEmailInviteStatusPending);
    expect(invite.entityId.v, entityId);
    expect(invite.entityName.v, entityId);
    expect(invite.inviterUserId.v, ownerUserId);
    expect(invite.timestamp.v, isNotNull);
    expect(invite.isRead, isTrue);
    expect(invite.isWrite, isFalse);
    expect(invite.isAdmin, isFalse);
    var fsInvite = (await getFsInvite(inviteId))!;
    expect(fsInvite.isPending, isTrue);
    expect(fsInvite.email.v, 'invited@test.local');

    // The same email again updates the pending invite.
    var inviteId2 = await client.createEntityEmailInvite(
      entityId: entityId,
      email: 'invited@test.local',
      fsUserAccess: TkCmsFsUserAccess()..write.v = true,
    );
    expect(inviteId2, inviteId);
    invites = await client.listEntityEmailInvites(
      entityId: entityId,
      status: tkCmsEmailInviteStatusPending,
    );
    expect(invites.length, 1);
    expect(invites.first.isWrite, isTrue);
    expect(
      await client.listEntityEmailInvites(
        entityId: entityId,
        status: tkCmsEmailInviteStatusAccepted,
      ),
      isEmpty,
    );

    await client.deleteEntityEmailInvite(
      entityId: entityId,
      inviteId: inviteId,
    );
    expect(await client.listEntityEmailInvites(entityId: entityId), isEmpty);
    expect(await getFsInvite(inviteId), isNull);
    // Deleting it again is fine.
    await client.deleteEntityEmailInvite(
      entityId: entityId,
      inviteId: inviteId,
    );

    await tearDownEntity(entityId, [ownerUserId]);
  });

  test('entity admin or app admin only', () async {
    var entityId = 'test_email_invite_access_entity';
    var ownerUserId = await setUpEntity(entityId);
    var inviteId = await client.createEntityEmailInvite(
      entityId: entityId,
      email: 'invited@test.local',
      fsUserAccess: TkCmsFsUserAccess()..read.v = true,
    );

    // The users, then their access set by the owner (the doc api).
    var readerUserId = await signInUnverified('reader@festenao-test.local');
    var strangerUserId = await signInUnverified('stranger@festenao-test.local');
    await signInOwner();
    var docApiService = apiService.docApiService;
    await docApiService.cvSetDoc(
      fsDatabase.projectDb.fsEntityUserAccessRef(entityId, readerUserId).cv()
        ..read.v = true
        ..fixAccess(),
    );

    // A reader of the entity cannot manage its email invites.
    await signInUnverified('reader@festenao-test.local');
    await expectLater(
      () => client.createEntityEmailInvite(
        entityId: entityId,
        email: 'other@test.local',
        fsUserAccess: TkCmsFsUserAccess()..read.v = true,
      ),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      () => client.listEntityEmailInvites(entityId: entityId),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      () => client.deleteEntityEmailInvite(
        entityId: entityId,
        inviteId: inviteId,
      ),
      throwsA(isA<ApiException>()),
    );

    // A stranger neither.
    await signInUnverified('stranger@festenao-test.local');
    await expectLater(
      () => client.createEntityEmailInvite(
        entityId: entityId,
        email: 'other@test.local',
        fsUserAccess: TkCmsFsUserAccess()..read.v = true,
      ),
      throwsA(isA<ApiException>()),
    );

    // Unless an app admin: no entity access needed, admin can be granted.
    await signInOwner();
    var appAdminRef = fsDatabase.appDb.fsEntityUserAccessRef(
      fsDatabase.app,
      strangerUserId,
    );
    await docApiService.cvSetDoc(appAdminRef.cv()..grantAdminAccess());
    await signInUnverified('stranger@festenao-test.local');
    var inviteId2 = await client.createEntityEmailInvite(
      entityId: entityId,
      email: 'other@test.local',
      fsUserAccess: TkCmsFsUserAccess()..grantAdminAccess(),
    );
    var invites = await client.listEntityEmailInvites(entityId: entityId);
    expect(invites.map((e) => e.inviteId.v).toSet(), {inviteId, inviteId2});
    expect(
      invites.firstWhere((e) => e.inviteId.v == inviteId2).isAdmin,
      isTrue,
    );
    expect(
      invites.firstWhere((e) => e.inviteId.v == inviteId2).inviterUserId.v,
      strangerUserId,
    );
    expect((await getFsInvite(inviteId))!.isPending, isTrue);

    await signInOwner();
    await docApiService.cvDeleteDoc(appAdminRef);
    await tearDownEntity(
      entityId,
      [ownerUserId, readerUserId, strangerUserId],
      inviteIds: [inviteId, inviteId2],
    );
  });

  test('check, accept by the invitee', () async {
    var entityId = 'test_email_invite_accept_entity';
    var invitedEmail = 'invited-accept@festenao-test.local';
    var ownerUserId = await setUpEntity(entityId);
    var inviteId = await client.createEntityEmailInvite(
      entityId: entityId,
      email: invitedEmail.toUpperCase(),
      fsUserAccess: TkCmsFsUserAccess()..write.v = true,
    );

    var invitedUserId = await signInVerified!(context, invitedEmail);
    var check = await client.checkEmailInvites();
    expect(check.emailVerified.v, isTrue);
    expect(check.email.v, invitedEmail);
    var invite = check.invites.v!.single;
    expect(invite.inviteId.v, inviteId);
    expect(invite.entityId.v, entityId);
    expect(invite.entityName.v, entityId);
    expect(invite.status.v, tkCmsEmailInviteStatusPending);
    expect(invite.inviterUserId.v, ownerUserId);
    expect(invite.isWrite, isTrue);
    expect(invite.isAdmin, isFalse);
    // Filtered by entity.
    expect((await client.checkEmailInvites(entityId: 'other')).invites.v, []);
    expect(
      (await client.checkEmailInvites(entityId: entityId)).invites.v!.length,
      1,
    );

    // The wrong entity, an unknown invite.
    await expectLater(
      () =>
          client.acceptEntityEmailInvite(entityId: 'other', inviteId: inviteId),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      () => client.acceptEntityEmailInvite(
        entityId: entityId,
        inviteId: 'missing',
      ),
      throwsA(isA<ApiException>()),
    );

    await client.acceptEntityEmailInvite(
      entityId: entityId,
      inviteId: inviteId,
    );
    var docApiService = apiService.docApiService;
    var entityUserAccess = (await docApiService.cvGetDoc(
      fsDatabase.projectDb.fsEntityUserAccessRef(entityId, invitedUserId),
    ))!;
    expect(entityUserAccess.inviteId.v, inviteId);
    expect(entityUserAccess.read.v, isTrue);
    expect(entityUserAccess.write.v, isTrue);
    expect(entityUserAccess.admin.v, isFalse);
    expect(
      await docApiService.cvGetDoc<TkCmsFsUserAccess>(
        fsDatabase.projectDb.fsUserEntityAccessRef(invitedUserId, entityId),
      ),
      entityUserAccess,
    );
    // No longer pending for the invitee, kept as accepted.
    expect((await client.checkEmailInvites()).invites.v, []);
    var fsInvite = (await getFsInvite(inviteId))!;
    expect(fsInvite.status.v, tkCmsEmailInviteStatusAccepted);
    expect(fsInvite.acceptedUserId.v, invitedUserId);
    expect(fsInvite.closedTimestamp.v, isNotNull);
    // Only once.
    await expectLater(
      () => client.acceptEntityEmailInvite(
        entityId: entityId,
        inviteId: inviteId,
      ),
      throwsA(isA<ApiException>()),
    );

    // The owner sees what happened.
    await signInOwner();
    var invites = await client.listEntityEmailInvites(entityId: entityId);
    expect(invites.single.inviteId.v, inviteId);
    expect(invites.single.status.v, tkCmsEmailInviteStatusAccepted);
    expect(
      await client.listEntityEmailInvites(
        entityId: entityId,
        status: tkCmsEmailInviteStatusPending,
      ),
      isEmpty,
    );

    await tearDownEntity(
      entityId,
      [ownerUserId, invitedUserId],
      inviteIds: [inviteId],
    );
  }, skip: skipVerified);

  test('another user cannot accept', () async {
    var entityId = 'test_email_invite_other_entity';
    var ownerUserId = await setUpEntity(entityId);
    var inviteId = await client.createEntityEmailInvite(
      entityId: entityId,
      email: 'invited-other@festenao-test.local',
      fsUserAccess: TkCmsFsUserAccess()..read.v = true,
    );

    // Verified, but not the invited address: nothing to see, nothing to
    // accept, even knowing the invite id.
    var otherUserId = await signInVerified!(
      context,
      'other-verified@festenao-test.local',
    );
    var check = await client.checkEmailInvites();
    expect(check.emailVerified.v, isTrue);
    expect(check.invites.v, []);
    await expectLater(
      () => client.acceptEntityEmailInvite(
        entityId: entityId,
        inviteId: inviteId,
      ),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      () => client.discardEntityEmailInvite(
        entityId: entityId,
        inviteId: inviteId,
      ),
      throwsA(isA<ApiException>()),
    );
    expect(
      await apiService.docApiService.cvGetDoc<TkCmsFsUserAccess>(
        fsDatabase.projectDb.fsEntityUserAccessRef(entityId, otherUserId),
      ),
      isNull,
    );
    expect((await getFsInvite(inviteId))!.isPending, isTrue);

    await tearDownEntity(
      entityId,
      [ownerUserId, otherUserId],
      inviteIds: [inviteId],
    );
  }, skip: skipVerified);

  test('unverified email: no invite listed, no accept', () async {
    var entityId = 'test_email_invite_unverified_entity';
    var invitedEmail = 'unverified@festenao-test.local';
    var ownerUserId = await setUpEntity(entityId);
    var inviteId = await client.createEntityEmailInvite(
      entityId: entityId,
      email: invitedEmail,
      fsUserAccess: TkCmsFsUserAccess()..read.v = true,
    );

    // The right address, not verified: the check says so and lists nothing,
    // accepting fails.
    var invitedUserId = await signInUnverified(invitedEmail);
    var check = await client.checkEmailInvites();
    expect(check.email.v, invitedEmail);
    expect(check.emailVerified.v, isFalse);
    expect(check.invites.v, []);
    await expectLater(
      () => client.acceptEntityEmailInvite(
        entityId: entityId,
        inviteId: inviteId,
      ),
      throwsA(isA<ApiException>()),
    );
    expect(
      await apiService.docApiService.cvGetDoc<TkCmsFsUserAccess>(
        fsDatabase.projectDb.fsEntityUserAccessRef(entityId, invitedUserId),
      ),
      isNull,
    );
    expect((await getFsInvite(inviteId))!.isPending, isTrue);

    await tearDownEntity(
      entityId,
      [ownerUserId, invitedUserId],
      inviteIds: [inviteId],
    );
  });

  test('discard by the invitee', () async {
    var entityId = 'test_email_invite_discard_entity';
    var invitedEmail = 'invited-discard@festenao-test.local';
    var ownerUserId = await setUpEntity(entityId);
    var inviteId = await client.createEntityEmailInvite(
      entityId: entityId,
      email: invitedEmail,
      fsUserAccess: TkCmsFsUserAccess()..read.v = true,
    );

    var invitedUserId = await signInVerified!(context, invitedEmail);
    expect((await client.checkEmailInvites()).invites.v!.length, 1);
    await client.discardEntityEmailInvite(
      entityId: entityId,
      inviteId: inviteId,
    );
    expect((await client.checkEmailInvites()).invites.v, []);
    var fsInvite = (await getFsInvite(inviteId))!;
    expect(fsInvite.status.v, tkCmsEmailInviteStatusDiscarded);
    expect(fsInvite.acceptedUserId.v, isNull);
    expect(fsInvite.closedTimestamp.v, isNotNull);
    expect(
      await apiService.docApiService.cvGetDoc<TkCmsFsUserAccess>(
        fsDatabase.projectDb.fsEntityUserAccessRef(entityId, invitedUserId),
      ),
      isNull,
    );
    // Final.
    await expectLater(
      () => client.acceptEntityEmailInvite(
        entityId: entityId,
        inviteId: inviteId,
      ),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      () => client.discardEntityEmailInvite(
        entityId: entityId,
        inviteId: inviteId,
      ),
      throwsA(isA<ApiException>()),
    );

    // The owner sees it, and can clean it up.
    await signInOwner();
    var invites = await client.listEntityEmailInvites(
      entityId: entityId,
      status: tkCmsEmailInviteStatusDiscarded,
    );
    expect(invites.single.inviteId.v, inviteId);
    await client.deleteEntityEmailInvite(
      entityId: entityId,
      inviteId: inviteId,
    );
    expect(await getFsInvite(inviteId), isNull);

    await tearDownEntity(entityId, [ownerUserId, invitedUserId]);
  }, skip: skipVerified);
}

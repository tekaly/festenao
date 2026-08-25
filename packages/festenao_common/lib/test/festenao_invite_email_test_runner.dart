import 'package:dev_test/test.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/src/data/firestore/firestore_doc_api.dart';
import 'package:tkcms_common/tkcms_api.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

import 'festenao_test_server_test_runner.dart';

/// Email of the user invited by email in [testFestenaoInviteEmailGroup].
///
/// Deliberately not lower cased, invites are matched on a normalized email.
const festenaoInviteTestEmail = 'Invited+Festenao@festenao-test.local';

/// Email of a user that is not the invited one.
const festenaoInviteTestOtherEmail = 'other@festenao-test.local';

/// Password of the test users.
const festenaoInviteTestPassword = 'test1234';

/// Test group for the invite by email api.
///
/// Covers [FestenaoApiFsEntityClient.createEntityInvite] /
/// [FestenaoApiFsEntityClient.createEntityEmailInvite] with an email and
/// [FestenaoApiFsEntityClient.acceptEntityInvite] email check.
void testFestenaoInviteEmailGroup(
  Future<FestenaoTestServerContext> Function() initAllContext,
) {
  late FestenaoTestServerContext context;
  late FestenaoApiService apiService;
  late FestenaoFirestoreDatabase fsDatabase;
  late FirebaseAuth auth;

  setUpAll(() async {
    context = await initAllContext();
    apiService = context.apiService;
    fsDatabase = context.fsDatabase;
    auth = context.clientContext.firebaseAuth!;
  });
  tearDownAll(() async {
    await context.close();
  });

  /// Sign in (or up) and return the user id.
  Future<String> signInEmail(String email) async {
    var userCredential = await auth.signInOrUpWithEmailAndPassword(
      email: email,
      password: festenaoInviteTestPassword,
    );
    return userCredential.user.uid;
  }

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

  /// Delete everything created for [entityId].
  Future<void> tearDownEntity(String entityId, List<String> userIds) async {
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
  }

  test('create/accept invite by email', () async {
    var client = context.projectApiClient;
    var docApiService = apiService.docApiService;
    var entityId = 'test_invite_email_entity';

    var ownerUserId = await setUpEntity(entityId);

    // The owner invites a user by email, with read access only.
    var inviteId = await client.createEntityEmailInvite(
      entityId: entityId,
      email: festenaoInviteTestEmail,
      fsUserAccess: TkCmsFsUserAccess()..read.v = true,
    );

    var inviteRef = fsDatabase.projectDb.fsInviteEntityRef(inviteId, entityId);
    var invite = (await docApiService.cvGetDoc(inviteRef))!;
    // The email is stored normalized (trimmed/lower cased).
    expect(invite.email.v, festenaoInviteTestEmail.toLowerCase());
    expect(invite.entityId.v, entityId);
    var inviteUserAccess = invite.userAccess.v!;
    expect(inviteUserAccess.isRead, isTrue);
    expect(inviteUserAccess.isWrite, isFalse);
    expect(inviteUserAccess.isAdmin, isFalse);

    // Another user cannot accept it, even knowing the invite id.
    var otherUserId = await signInEmail(festenaoInviteTestOtherEmail);
    // No email supplied.
    await expectLater(
      () => client.acceptEntityInvite(entityId: entityId, inviteId: inviteId),
      throwsA(isA<ApiException>()),
    );
    // Wrong email supplied.
    await expectLater(
      () => client.acceptEntityInvite(
        entityId: entityId,
        inviteId: inviteId,
        email: festenaoInviteTestOtherEmail,
      ),
      throwsA(isA<ApiException>()),
    );
    // Nothing was granted and the invite is still there.
    expect(
      await docApiService.cvGetDoc<TkCmsFsUserAccess>(
        fsDatabase.projectDb.fsEntityUserAccessRef(entityId, otherUserId),
      ),
      isNull,
    );
    expect(
      await docApiService.cvGetDoc<TkCmsFsInviteEntity<FsProject>>(inviteRef),
      isNotNull,
    );

    // The invited user accepts it, the email casing does not matter.
    var invitedUserId = await signInEmail(festenaoInviteTestEmail);
    expect(invitedUserId, isNot(otherUserId));
    await client.acceptEntityInvite(
      entityId: entityId,
      inviteId: inviteId,
      email: festenaoInviteTestEmail.toUpperCase(),
    );

    var entityUserAccess = (await docApiService.cvGetDoc(
      fsDatabase.projectDb.fsEntityUserAccessRef(entityId, invitedUserId),
    ))!;
    var userEntityAccess = (await docApiService.cvGetDoc(
      fsDatabase.projectDb.fsUserEntityAccessRef(invitedUserId, entityId),
    ))!;
    expect(entityUserAccess.inviteId.v, inviteId);
    expect(entityUserAccess.read.v, isTrue);
    expect(entityUserAccess.write.v, isFalse);
    expect(entityUserAccess.admin.v, isFalse);
    expect(entityUserAccess, userEntityAccess);

    // The invite is consumed.
    expect(
      await docApiService.cvGetDoc<TkCmsFsInviteEntity<FsProject>>(inviteRef),
      isNull,
    );
    expect(
      await docApiService.cvGetDoc<TkCmsFsInviteId>(
        fsDatabase.projectDb.fsInviteIdRef(inviteId),
      ),
      isNull,
    );

    await tearDownEntity(entityId, [ownerUserId, invitedUserId, otherUserId]);
    await signInOwner();
  });

  test('invite by email is not reusable', () async {
    var client = context.projectApiClient;
    var docApiService = apiService.docApiService;
    var entityId = 'test_invite_email_once_entity';

    var ownerUserId = await setUpEntity(entityId);
    var inviteId = await client.createEntityInvite(
      entityId: entityId,
      email: festenaoInviteTestEmail,
      fsUserAccess: TkCmsFsUserAccess()..grantAdminAccess(),
    );

    var invitedUserId = await signInEmail(festenaoInviteTestEmail);
    await client.acceptEntityInvite(
      entityId: entityId,
      inviteId: inviteId,
      email: festenaoInviteTestEmail,
    );
    var entityUserAccess = (await docApiService.cvGetDoc(
      fsDatabase.projectDb.fsEntityUserAccessRef(entityId, invitedUserId),
    ))!;
    expect(entityUserAccess.isAdmin, isTrue);

    // Accepting again fails, the invite no longer exists.
    await expectLater(
      () => client.acceptEntityInvite(
        entityId: entityId,
        inviteId: inviteId,
        email: festenaoInviteTestEmail,
      ),
      throwsA(isA<ApiException>()),
    );

    await tearDownEntity(entityId, [ownerUserId, invitedUserId]);
    await signInOwner();
  });

  test('invite without email is accepted by anyone', () async {
    var client = context.projectApiClient;
    var docApiService = apiService.docApiService;
    var entityId = 'test_invite_no_email_entity';

    var ownerUserId = await setUpEntity(entityId);
    var inviteId = await client.createEntityInvite(
      entityId: entityId,
      fsUserAccess: TkCmsFsUserAccess()..read.v = true,
    );
    var inviteRef = fsDatabase.projectDb.fsInviteEntityRef(inviteId, entityId);
    expect(
      (await docApiService.cvGetDoc<TkCmsFsInviteEntity<FsProject>>(
        inviteRef,
      ))!.email.v,
      isNull,
    );

    // Any user can accept it, whatever email is supplied.
    var otherUserId = await signInEmail(festenaoInviteTestOtherEmail);
    await client.acceptEntityInvite(entityId: entityId, inviteId: inviteId);
    expect(
      (await docApiService.cvGetDoc(
        fsDatabase.projectDb.fsEntityUserAccessRef(entityId, otherUserId),
      ))!.read.v,
      isTrue,
    );

    await tearDownEntity(entityId, [ownerUserId, otherUserId]);
    await signInOwner();
  });

  test('delete an invite by email', () async {
    var client = context.projectApiClient;
    var docApiService = apiService.docApiService;
    var entityId = 'test_invite_email_delete_entity';

    var ownerUserId = await setUpEntity(entityId);
    var inviteId = await client.createEntityEmailInvite(
      entityId: entityId,
      email: festenaoInviteTestEmail,
      fsUserAccess: TkCmsFsUserAccess()..read.v = true,
    );
    var inviteRef = fsDatabase.projectDb.fsInviteEntityRef(inviteId, entityId);
    expect(
      await docApiService.cvGetDoc<TkCmsFsInviteEntity<FsProject>>(inviteRef),
      isNotNull,
    );

    await client.deleteEntityInvite(entityId: entityId, inviteId: inviteId);
    expect(
      await docApiService.cvGetDoc<TkCmsFsInviteEntity<FsProject>>(inviteRef),
      isNull,
    );
    expect(
      await docApiService.cvGetDoc<TkCmsFsInviteId>(
        fsDatabase.projectDb.fsInviteIdRef(inviteId),
      ),
      isNull,
    );

    // The invited user can no longer accept it.
    var invitedUserId = await signInEmail(festenaoInviteTestEmail);
    await expectLater(
      () => client.acceptEntityInvite(
        entityId: entityId,
        inviteId: inviteId,
        email: festenaoInviteTestEmail,
      ),
      throwsA(isA<ApiException>()),
    );

    await tearDownEntity(entityId, [ownerUserId, invitedUserId]);
    await signInOwner();
  });
}

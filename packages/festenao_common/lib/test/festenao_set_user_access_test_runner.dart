import 'package:dev_test/test.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/api/festenao_api_fs_entity_client.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/src/data/firestore/firestore_doc_api.dart';
import 'package:tkcms_common/tkcms_api.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

import 'festenao_invite_email_test_runner.dart' show festenaoInviteTestPassword;
import 'festenao_test_server_test_runner.dart';

/// Test group for the set user access command: an admin gives a user an
/// access to an entity right away, by email or by id, without an invite.
///
/// The rights, checked by the server handler: an admin of the entity or an
/// app admin, not on itself; roles granted only when held (or by an app
/// super admin), a super admin changed only by a super admin; an email
/// without an account is `not-found` (the app invites it then).
///
/// [createUser] creates a user with a name (see
/// `festenaoLocalAuthCreateUser`); without it the group is skipped.
void testFestenaoSetUserAccessGroup(
  Future<FestenaoTestServerContext> Function() initAllContext, {
  Future<String> Function(
    FestenaoTestServerContext context, {
    required String email,
    String? displayName,
    bool emailVerified,
  })?
  createUser,
  bool closeContext = true,
}) {
  late FestenaoTestServerContext context;
  late FestenaoApiService apiService;
  late FestenaoFirestoreDatabase fsDatabase;
  late FirebaseAuth auth;
  late FestenaoApiFsEntityClient<FsProject> client;
  var skip = createUser == null
      ? 'needs users with a name (no createUser hook)'
      : null;

  const entityId = 'test_set_user_access_entity';
  const memberEmail = 'lea.member@festenao-test.local';
  const readerEmail = 'paul.reader@festenao-test.local';
  const strangerEmail = 'zoe.stranger@festenao-test.local';
  late String ownerUserId;
  late String memberUserId;
  late String readerUserId;
  late String strangerUserId;

  Future<String> signInOwner() async {
    var credentials = context.clientContext.credentials!;
    await auth.signOut();
    var userCredential = await auth.signInOrUpWithEmailAndPassword(
      email: credentials.email,
      password: credentials.password,
    );
    return userCredential.user.uid;
  }

  Future<void> signIn(String email) async {
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: email,
      password: festenaoInviteTestPassword,
    );
  }

  Future<String> expectApiError(
    Future<Object?> Function() call,
    String code,
  ) async {
    try {
      await call();
      fail('should fail with $code');
    } on ApiException catch (e) {
      expect(e.error?.code.v, code, reason: '$e');
      return e.message ?? '';
    }
  }

  CvDocumentReference<TkCmsFsUserAccess> accessRef(String userId) =>
      fsDatabase.projectDb.fsEntityUserAccessRef(entityId, userId);

  /// The access of [userId] (entity side, read as the owner), checked equal
  /// to its user side; null when none.
  Future<TkCmsEditedFsUserAccess?> accessOf(String userId) async {
    var docApiService = apiService.docApiService;
    var entitySide = await docApiService.cvGetDoc(
      accessRef(userId).cast<TkCmsEditedFsUserAccess>(),
    );
    var userSide = await docApiService.cvGetDoc(
      fsDatabase.projectDb.fsUserEntityAccessRef(userId, entityId),
    );
    expect(userSide == null, entitySide == null);
    if (entitySide == null || userSide == null) {
      return null;
    }
    expect(userSide.isAdmin, entitySide.isAdmin);
    expect(userSide.roles, entitySide.roles);
    return entitySide;
  }

  Future<FsCmsEntitySetUserAccessApiResult<FsProject>> set({
    String? userId,
    String? email,
    required TkCmsCvUserAccess userAccess,
  }) => client.setEntityUserAccess(
    entityId: entityId,
    userId: userId,
    email: email,
    userAccess: userAccess,
  );

  TkCmsCvUserAccess write() => TkCmsCvUserAccess()
    ..write.v = true
    ..fixAccess();

  setUpAll(() async {
    context = await initAllContext();
    apiService = context.apiService;
    fsDatabase = context.fsDatabase;
    auth = context.clientContext.firebaseAuth!;
    client = context.projectApiClient;
    if (skip != null) {
      return;
    }
    memberUserId = await createUser!(
      context,
      email: memberEmail,
      displayName: 'Léa Moreau',
      emailVerified: true,
    );
    readerUserId = await createUser(
      context,
      email: readerEmail,
      displayName: 'Paul Petit',
    );
    strangerUserId = await createUser(
      context,
      email: strangerEmail,
      displayName: 'Zoé Roux',
    );
  });

  setUp(() async {
    if (skip != null) {
      return;
    }
    // The owner is admin of the entity, the reader reads, nobody else.
    ownerUserId = await signInOwner();
    var docApiService = apiService.docApiService;
    await docApiService.cvSetDoc(
      fsDatabase.projectDb.fsEntityRef(entityId).cv()..name.v = entityId,
    );
    await docApiService.cvSetDoc(
      accessRef(ownerUserId).cv()..grantAdminAccess(),
    );
    for (var userId in [memberUserId, strangerUserId]) {
      await client.setEntityUserAccess(
        entityId: entityId,
        userId: userId,
        userAccess: TkCmsCvUserAccess(),
      );
    }
    await docApiService.cvSetDoc(
      accessRef(readerUserId).cv()
        ..read.v = true
        ..fixAccess(),
    );
  });

  tearDownAll(() async {
    if (skip == null) {
      await signInOwner();
      var docApiService = apiService.docApiService;
      for (var userId in [
        memberUserId,
        readerUserId,
        strangerUserId,
        ownerUserId,
      ]) {
        await docApiService.cvDeleteDoc(accessRef(userId));
        await docApiService.cvDeleteDoc(
          fsDatabase.projectDb.fsUserEntityAccessRef(userId, entityId),
        );
      }
      await docApiService.cvDeleteDoc(
        fsDatabase.projectDb.fsEntityRef(entityId),
      );
    }
    if (closeContext) {
      await context.close();
    }
  });

  test('an entity admin adds a user by email, no invite', () async {
    await signInOwner();
    var result = await set(
      email: ' LEA.member@festenao-test.local ',
      userAccess: write(),
    );
    expect(result.userId.v, memberUserId);
    expect(result.name.v, 'Léa Moreau');
    expect(result.email.v, memberEmail);
    expect(result.isWrite, isTrue);
    expect(result.isAdmin, isFalse);
    var access = (await accessOf(memberUserId))!;
    expect(access.isWrite, isTrue);
    expect(access.isRead, isTrue);
    expect(access.name.v, 'Léa Moreau');
    expect(access.email.v, memberEmail);

    // Made an admin by id, then removed.
    result = await set(
      userId: memberUserId,
      userAccess: TkCmsCvUserAccess()..grantAdminAccess(),
    );
    expect(result.isAdmin, isTrue);
    expect((await accessOf(memberUserId))!.isAdmin, isTrue);
    result = await set(userId: memberUserId, userAccess: TkCmsCvUserAccess());
    expect(result.isRead, isFalse);
    expect(await accessOf(memberUserId), isNull);
  }, skip: skip);

  test('an email without an account: not found, invite it', () async {
    await signInOwner();
    var message = await expectApiError(
      () => set(email: 'nobody@festenao-test.local', userAccess: write()),
      'not-found',
    );
    expect(message, contains('nobody@festenao-test.local'));
    await expectApiError(() => set(userAccess: write()), 'invalid-argument');
  }, skip: skip);

  test('only an admin, never on itself', () async {
    await signIn(readerEmail);
    await expectApiError(
      () => set(email: memberEmail, userAccess: write()),
      'permission-denied',
    );
    await signIn(strangerEmail);
    await expectApiError(
      () => set(email: memberEmail, userAccess: write()),
      'permission-denied',
    );
    await signInOwner();
    await expectApiError(
      () => set(userId: ownerUserId, userAccess: TkCmsCvUserAccess()),
      'permission-denied',
    );
    await auth.signOut();
    try {
      await set(email: memberEmail, userAccess: write());
      fail('should fail');
    } on ApiException catch (e) {
      expect(e.error?.code.v, isNotNull, reason: '$e');
    }
  }, skip: skip);

  test('roles: held by the caller, or an app super admin', () async {
    await signInOwner();
    TkCmsCvUserAccess withRole(String role) => TkCmsCvUserAccess()
      ..grantAdminAccess()
      ..role.v = role;
    // The owner holds no role: none granted, by access or invite.
    var message = await expectApiError(
      () => set(email: memberEmail, userAccess: withRole(roleSuperAdmin)),
      'permission-denied',
    );
    expect(message, contains(roleSuperAdmin));
    await expectApiError(
      () => client.sendEntityEmailInvite(
        entityId: entityId,
        email: 'invitee@festenao-test.local',
        fsUserAccess: TkCmsFsUserAccess()..copyAccessFrom(withRole('slug')),
      ),
      'permission-denied',
    );

    // An app super admin grants it.
    var docApiService = apiService.docApiService;
    var appAdminRef = fsDatabase.appDb.fsEntityUserAccessRef(
      fsDatabase.app,
      strangerUserId,
    );
    await docApiService.cvSetDoc(appAdminRef.cv()..grantSuperAdminAccess());
    try {
      await signIn(strangerEmail);
      var result = await set(
        email: memberEmail,
        userAccess: withRole(roleSuperAdmin),
      );
      expect(result.hasSuperAdminRole, isTrue);
      expect(
        (await accessOfAsOwner(
          signInOwner,
          accessOf,
          memberUserId,
        ))!.hasSuperAdminRole,
        isTrue,
      );

      // A role held already is kept by a plain entity admin: the member
      // gets a role, then is made an editor keeping it.
      await signIn(strangerEmail);
      await set(email: readerEmail, userAccess: withRole('slug'));
      await signInOwner();
      var reader = await set(
        email: readerEmail,
        userAccess: TkCmsCvUserAccess()
          ..write.v = true
          ..role.v = 'slug'
          ..fixAccess(),
      );
      expect(reader.isWrite, isTrue);
      expect(reader.isAdmin, isFalse);
      expect(reader.roles, ['slug']);

      // A plain entity admin no longer changes it.
      await signInOwner();
      await expectApiError(
        () => set(userId: memberUserId, userAccess: write()),
        'permission-denied',
      );
    } finally {
      await signInOwner();
      await docApiService.cvDeleteDoc(appAdminRef);
    }
  }, skip: skip);
}

/// [accessOf] read signed in as the owner ([signInOwner]).
Future<TkCmsEditedFsUserAccess?> accessOfAsOwner(
  Future<String> Function() signInOwner,
  Future<TkCmsEditedFsUserAccess?> Function(String userId) accessOf,
  String userId,
) async {
  await signInOwner();
  return accessOf(userId);
}

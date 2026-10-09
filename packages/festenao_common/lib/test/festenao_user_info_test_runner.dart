import 'package:dev_test/test.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/api/festenao_api_fs_entity.dart';
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

/// Creates (once) a user with [email], [displayName] and a verified or not
/// email on a local auth that implements the admin api (the in memory
/// server), returns its id. The current user is left signed in.
Future<String> festenaoLocalAuthCreateUser(
  FestenaoTestServerContext context, {
  required String email,
  String? displayName,
  bool emailVerified = false,
}) async {
  var auth = context.clientContext.firebaseAuth!;
  var existing = await auth.getUserByEmail(email);
  if (existing != null) {
    return existing.uid;
  }
  var user = await (auth as FirebaseAuthAdmin).createUser(
    FirebaseAuthCreateUserRequest(
      email: email,
      password: festenaoInviteTestPassword,
      displayName: displayName,
      emailVerified: emailVerified,
    ),
  );
  return user.uid;
}

/// Test group for the get user info command: an admin reads the name and the
/// email of a user to fill an access being edited.
///
/// The rights, checked by the server handler: an app admin reads any user,
/// an admin of the entity only the users that have an access to it, a
/// reader, a stranger or a signed out caller nobody.
///
/// [createUser] creates a user with a name (see
/// [festenaoLocalAuthCreateUser]); without it the group is skipped (the
/// emulator context has no such hook yet).
void testFestenaoUserInfoGroup(
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

  const entityId = 'test_user_info_entity';
  const memberEmail = 'camille.member@festenao-test.local';
  const readerEmail = 'hugo.reader@festenao-test.local';
  const strangerEmail = 'ines.stranger@festenao-test.local';
  late String ownerUserId;
  late String memberUserId;
  late String readerUserId;
  late String strangerUserId;

  /// Sign in as the owner (the context credentials user) and return its id.
  Future<String> signInOwner() async {
    var credentials = context.clientContext.credentials;
    if (credentials == null) {
      throw StateError('Auth and credentials are required for this test');
    }
    await auth.signOut();
    var userCredential = await auth.signInOrUpWithEmailAndPassword(
      email: credentials.email,
      password: credentials.password,
    );
    return userCredential.user.uid;
  }

  /// Sign in as an existing test user.
  Future<void> signIn(String email) async {
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: email,
      password: festenaoInviteTestPassword,
    );
  }

  /// Expect the call to be refused with [code].
  Future<void> expectApiError(
    Future<Object?> Function() call,
    String code,
  ) async {
    try {
      await call();
      fail('should fail with $code');
    } on ApiException catch (e) {
      expect(e.error?.code.v, code, reason: '$e');
    }
  }

  Future<FsCmsEntityGetUserInfoApiResult<FsProject>> getInfo(String userId) =>
      client.getEntityUserInfo(entityId: entityId, userId: userId);

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
      displayName: 'Camille Martin',
      emailVerified: true,
    );
    readerUserId = await createUser(
      context,
      email: readerEmail,
      displayName: 'Hugo Bernard',
    );
    strangerUserId = await createUser(
      context,
      email: strangerEmail,
      displayName: 'Inès Dubois',
    );

    // The entity: the owner is admin, the member writes, the reader reads,
    // the stranger has nothing. Set through the doc api (admin side).
    ownerUserId = await signInOwner();
    var docApiService = apiService.docApiService;
    await docApiService.cvSetDoc(
      fsDatabase.projectDb.fsEntityRef(entityId).cv()..name.v = entityId,
    );
    await docApiService.cvSetDoc(
      fsDatabase.projectDb.fsEntityUserAccessRef(entityId, ownerUserId).cv()
        ..grantAdminAccess(),
    );
    await docApiService.cvSetDoc(
      fsDatabase.projectDb.fsEntityUserAccessRef(entityId, memberUserId).cv()
        ..write.v = true
        ..fixAccess(),
    );
    await docApiService.cvSetDoc(
      fsDatabase.projectDb.fsEntityUserAccessRef(entityId, readerUserId).cv()
        ..read.v = true
        ..fixAccess(),
    );
  });

  tearDownAll(() async {
    if (skip == null) {
      await signInOwner();
      var docApiService = apiService.docApiService;
      for (var userId in [
        ownerUserId,
        memberUserId,
        readerUserId,
        strangerUserId,
      ]) {
        await docApiService.cvDeleteDoc(
          fsDatabase.projectDb.fsEntityUserAccessRef(entityId, userId),
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

  test('an entity admin reads a member', () async {
    await signInOwner();
    var info = await getInfo(memberUserId);
    expect(info.userId.v, memberUserId);
    expect(info.name.v, 'Camille Martin');
    expect(info.email.v, memberEmail);
    expect(info.emailVerified.v, isTrue);
    expect(info.disabled.v, isFalse);
    expect(info.hasAccess.v, isTrue);

    // A reader is a member too, its email is not verified.
    info = await getInfo(readerUserId);
    expect(info.name.v, 'Hugo Bernard');
    expect(info.email.v, readerEmail);
    expect(info.emailVerified.v, isFalse);
    expect(info.hasAccess.v, isTrue);

    // And the admin itself.
    info = await getInfo(ownerUserId);
    expect(info.email.v, context.clientContext.credentials!.email);
    expect(info.hasAccess.v, isTrue);
  }, skip: skip);

  test('an entity admin does not read a user without access', () async {
    await signInOwner();
    await expectApiError(() => getInfo(strangerUserId), 'permission-denied');
    // Nor an unknown user: no way to probe the accounts.
    await expectApiError(() => getInfo('no_such_user'), 'permission-denied');
  }, skip: skip);

  test('a reader, a writer or a stranger reads nobody', () async {
    await signIn(readerEmail);
    await expectApiError(() => getInfo(ownerUserId), 'permission-denied');
    await expectApiError(() => getInfo(memberUserId), 'permission-denied');

    await signIn(memberEmail);
    await expectApiError(() => getInfo(readerUserId), 'permission-denied');

    await signIn(strangerEmail);
    await expectApiError(() => getInfo(ownerUserId), 'permission-denied');
    await expectApiError(() => getInfo(strangerUserId), 'permission-denied');
  }, skip: skip);

  test('signed out, nothing', () async {
    await auth.signOut();
    try {
      await getInfo(memberUserId);
      fail('should fail');
    } on ApiException catch (e) {
      expect(e.error?.code.v, isNotNull, reason: '$e');
    }
  }, skip: skip);

  test('an app admin reads any user', () async {
    // The stranger becomes an app admin.
    await signInOwner();
    var docApiService = apiService.docApiService;
    var appAdminRef = fsDatabase.appDb.fsEntityUserAccessRef(
      fsDatabase.app,
      strangerUserId,
    );
    await docApiService.cvSetDoc(appAdminRef.cv()..grantAdminAccess());
    try {
      await signIn(strangerEmail);
      // A member of the entity.
      var info = await getInfo(memberUserId);
      expect(info.name.v, 'Camille Martin');
      expect(info.email.v, memberEmail);
      expect(info.hasAccess.v, isTrue);

      // Itself, without access to the entity.
      info = await getInfo(strangerUserId);
      expect(info.name.v, 'Inès Dubois');
      expect(info.email.v, strangerEmail);
      expect(info.hasAccess.v, isFalse);

      // An unknown user.
      await expectApiError(() => getInfo('no_such_user'), 'not-found');
    } finally {
      await signInOwner();
      await docApiService.cvDeleteDoc(appAdminRef);
    }

    // No longer an app admin.
    await signIn(strangerEmail);
    await expectApiError(() => getInfo(memberUserId), 'permission-denied');
  }, skip: skip);

  test('missing fields', () async {
    await signInOwner();
    await expectApiError(
      () => client.getEntityUserInfo(entityId: entityId, userId: ''),
      'invalid-argument',
    );
    await expectApiError(
      () => apiService.getApiResult<FsCmsEntityGetUserInfoApiResult<FsProject>>(
        ApiRequest(command: client.entityAccess.info.getUserInfoCommand)
          ..setQuery(
            FsCmsEntityGetUserInfoApiQuery<FsProject>()
              ..entityId.setValue(entityId),
          ),
      ),
      'invalid-argument',
    );
  }, skip: skip);
}

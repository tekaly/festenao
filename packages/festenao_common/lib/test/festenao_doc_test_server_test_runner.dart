import 'package:dev_test/test.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/src/data/firestore/firestore_doc_api.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

import 'festenao_test_server_test_runner.dart';

/// Test doc server group.
void testFestenaoDocServerGroup(
  Future<FestenaoTestServerContext> Function() initAllContext,
) {
  late FestenaoTestServerContext context;
  late FestenaoApiService apiService;
  setUpAll(() async {
    context = await initAllContext();
    apiService = context.apiService;
  });
  tearDownAll(() async {
    await context.close();
  });

  test('create/join/invite/DocEntity', () async {
    var auth = context.clientContext.firebaseAuth!;

    var client = context.projectApiClient;
    var fsDatabase = context.fsDatabase;
    var docApiService = apiService.docApiService;

    await auth.signOut();
    var authMe = await client.apiService.getAuthMe();
    expect(authMe.uid.v, isNull);

    var now = DateTime.timestamp().toIso8601String();
    var name = 'Test $now';
    var entityId = 'test_doc_entity';

    var credentials = context.clientContext.credentials;
    if (credentials == null) {
      throw StateError('Auth and credentials are required for this test');
    }
    var user = await auth.signInOrUpWithEmailAndPassword(
      email: credentials.email,
      password: credentials.password,
    );
    var userId = user.user.uid;

    // Grants admin access using docApiService
    var accessRef = fsDatabase.projectDb.fsEntityUserAccessRef(
      entityId,
      userId,
    );
    await docApiService.cvSetDoc(accessRef.cv()..grantAdminAccess());

    // Create entity using docApiService
    var entityRef = fsDatabase.projectDb.fsEntityRef(entityId);
    await docApiService.cvSetDoc(entityRef.cv()..name.v = name);

    var retrievedEntity = (await docApiService.cvGetDoc(entityRef))!;
    expect(retrievedEntity.name.v, name);

    // Create invite using client API
    var fsUserAccessRead = TkCmsFsUserAccess()..read.v = true;
    var inviteId = await client.createEntityInvite(
      entityId: entityId,
      fsUserAccess: fsUserAccessRead,
    );

    var inviteRef = fsDatabase.projectDb.fsInviteEntityRef(inviteId, entityId);
    var invite = (await docApiService.cvGetDoc(inviteRef))!;
    var userAccess = invite.userAccess.v!;
    expect(userAccess.isAdmin, isFalse);
    expect(userAccess.isWrite, isFalse);
    expect(userAccess.isRead, isTrue);
    expect(invite.entity.v!.name.v, name);
    expect(invite.entityId.v, entityId);
    expect(invite.timestamp.v, isNotNull);

    // Accept invite with a second user
    var userId2 = await auth
        .signInOrUpWithEmailAndPassword(
          email: 'alex+festenao-test@tekartik.com',
          password: 'test1234',
        )
        .then((credentials) => credentials.user.uid);

    var inviteIdRef = fsDatabase.projectDb.fsInviteIdRef(inviteId);
    var inviteIdDoc = (await docApiService.cvGetDoc(inviteIdRef))!;
    expect(inviteIdDoc.timestamp.v, isNotNull);

    await client.acceptEntityInvite(entityId: entityId, inviteId: inviteId);

    var entityUserAccessRef = fsDatabase.projectDb.fsEntityUserAccessRef(
      entityId,
      userId2,
    );
    var userEntityAccessRef = fsDatabase.projectDb.fsUserEntityAccessRef(
      userId2,
      entityId,
    );
    var entityUserAccess = (await docApiService.cvGetDoc(entityUserAccessRef))!;
    var userEntityAccess = (await docApiService.cvGetDoc(userEntityAccessRef))!;

    expect(entityUserAccess.inviteId.v, inviteId);
    expect(entityUserAccess.admin.v, isFalse);
    expect(entityUserAccess.write.v, isFalse);
    expect(entityUserAccess.read.v, isTrue);
    expect(entityUserAccess, userEntityAccess);

    expect(await docApiService.cvGetDoc(inviteIdRef), isNull);
    expect(await docApiService.cvGetDoc(inviteRef), isNull);

    // Cleanup
    await docApiService.cvDeleteDoc(entityRef);
    await docApiService.cvDeleteDoc(accessRef);
    await docApiService.cvDeleteDoc(entityUserAccessRef);
    await docApiService.cvDeleteDoc(userEntityAccessRef);

    // Sign back as user 1
    await auth.signInWithEmailAndPassword(
      email: credentials.email,
      password: credentials.password,
    );
  });

  test('cleanup cron', () async {
    var db = context.fsDatabase.projectDb;
    var docApiService = apiService.docApiService;
    var now = Timestamp.now();
    var inviteId1 = 'invite1';
    var inviteId2 = 'invite2';
    var entityId = 'project1';
    var fsInviteId1Ref = db.fsInviteIdRef(inviteId1);
    var fsInviteId1 = fsInviteId1Ref.cv()
      ..entityId.v = entityId
      ..timestamp.v = now.substractDuration(
        tkCmsInviteEntityExpirationDefault - const Duration(minutes: 1),
      );
    var fsInviteId2Ref = db.fsInviteIdRef(inviteId2);
    var fsInviteId2 = fsInviteId2Ref.cv()
      ..entityId.v = entityId
      ..timestamp.v = now.substractDuration(
        tkCmsInviteEntityExpirationDefault + const Duration(minutes: 1),
      );
    var fsInviteEntity1Ref = db.fsInviteEntityRef(inviteId1, entityId);
    var fsInviteEntity2Ref = db.fsInviteEntityRef(inviteId2, entityId);

    var fsInviteEntity1 = fsInviteEntity1Ref.cv()..entityId.v = entityId;
    var fsInviteEntity2 = fsInviteEntity2Ref.cv();

    await docApiService.cvSetDoc(fsInviteId1);
    await docApiService.cvSetDoc(fsInviteId2);
    await docApiService.cvSetDoc(fsInviteEntity1);
    await docApiService.cvSetDoc(fsInviteEntity2);

    expect(
      await docApiService.cvGetDoc<TkCmsFsInviteId>(fsInviteId1Ref),
      isNotNull,
    );
    expect(
      await docApiService.cvGetDoc<TkCmsFsInviteId>(fsInviteId2Ref),
      isNotNull,
    );
    expect(
      await docApiService.cvGetDoc<TkCmsFsInviteEntity<FsProject>>(
        fsInviteEntity1Ref,
      ),
      isNotNull,
    );
    expect(
      await docApiService.cvGetDoc<TkCmsFsInviteEntity<FsProject>>(
        fsInviteEntity2Ref,
      ),
      isNotNull,
    );

    await apiService.cron();

    expect(
      await docApiService.cvGetDoc<TkCmsFsInviteId>(fsInviteId1Ref),
      isNotNull,
    );
    expect(
      await docApiService.cvGetDoc<TkCmsFsInviteEntity<FsProject>>(
        fsInviteEntity1Ref,
      ),
      isNotNull,
    );
    expect(
      await docApiService.cvGetDoc<TkCmsFsInviteId>(fsInviteId2Ref),
      isNull,
    );
    expect(
      await docApiService.cvGetDoc<TkCmsFsInviteEntity<FsProject>>(
        fsInviteEntity2Ref,
      ),
      isNull,
    );

    // Cleanup
    await docApiService.cvDeleteDoc(fsInviteId1Ref);
    await docApiService.cvDeleteDoc(fsInviteEntity1Ref);
  });
}

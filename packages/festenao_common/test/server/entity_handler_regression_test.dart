@TestOn('vm')
library;

import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/test/festenao_email_invite_test_runner.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// The app whose projects have a create limit, no user plan handler set.
const _limitedApp = 'limited_app_no_plan';

const _timeout = Timeout(Duration(seconds: 60));

/// Regressions of the entity handler (level 12 review).
void main() {
  late FestenaoTestServerContext context;
  late FestenaoProjectsServerApp serverApp;
  late FestenaoApiFsEntityClient<FsProject> client;

  setUpAll(() async {
    context = await initFestenaoTestServerContextAllMemory();
    serverApp = context.ffContext.serverApp as FestenaoProjectsServerApp;
    client = context.projectApiClient;
    serverApp.addAppProjectHandler(
      _limitedApp,
      options: FestenaoEntityHandlerOptions(createLimit: () => 2),
    );
  });
  tearDownAll(() async {
    await context.close();
  });

  Future<String> create(String name) async =>
      (await client.createEntity(entity: FsProject()..name.v = name)).id;

  test('a create limit without a user plan handler', () async {
    // No FestenaoUserPlanHandler: the entity handler registers the plan
    // and creator models itself.
    var limitedClient = FestenaoApiFsEntityClient<FsProject>(
      apiService: FestenaoApiService(
        callableApi: context.apiService.callableApi,
        httpClientFactory: httpClientFactoryMemory,
        app: _limitedApp,
      ),
      entityAccess: context.fsDatabase.copyWithAppId(_limitedApp).projectDb,
    );
    await festenaoLocalAuthSignInVerified(context, 'no.plan@test.local');
    var limit = await limitedClient.getCreateLimit();
    expect(limit.createLimit.v, 2);
    expect(limit.createCount.v, 0);
    await limitedClient.createEntity(entity: FsProject()..name.v = 'One');
    expect((await limitedClient.getCreateLimit()).createCount.v, 1);
  }, timeout: _timeout);

  test('delete invite: only an invite of the named entity', () async {
    await festenaoLocalAuthSignInVerified(context, 'owner@test.local');
    var victimId = await create('Victim');
    var inviteId = await client.createEntityInvite(
      entityId: victimId,
      fsUserAccess: TkCmsFsUserAccess()..read.v = true,
    );

    await festenaoLocalAuthSignInVerified(context, 'attacker@test.local');
    var ownId = await create('Own');
    // Admin of its own entity, naming the invite of another one.
    await expectLater(
      client.deleteEntityInvite(entityId: ownId, inviteId: inviteId),
      throwsA(
        isA<ApiException>().having(
          (e) => e.error?.code.v,
          'code',
          HttpsErrorCode.notFound,
        ),
      ),
    );

    // The invite still works.
    var guestId = await festenaoLocalAuthSignInVerified(
      context,
      'guest@test.local',
    );
    await client.acceptEntityInvite(entityId: victimId, inviteId: inviteId);
    var access = await context.fsDatabase.projectDb
        .fsEntityUserAccessRef(victimId, guestId)
        .get(context.fsDatabase.firestore);
    expect(access.isRead, isTrue);

    // Its own entity admin still deletes an invite.
    await festenaoLocalAuthSignInVerified(context, 'owner@test.local');
    var otherInviteId = await client.createEntityInvite(
      entityId: victimId,
      fsUserAccess: TkCmsFsUserAccess()..read.v = true,
    );
    await client.deleteEntityInvite(
      entityId: victimId,
      inviteId: otherInviteId,
    );
    expect(
      (await context.fsDatabase.projectDb
              .fsInviteIdRef(otherInviteId)
              .get(context.fsDatabase.firestore))
          .exists,
      isFalse,
    );
  }, timeout: _timeout);

  test('an invite reserved to an email: the caller account email', () async {
    await festenaoLocalAuthSignInVerified(context, 'reserved.owner@test.local');
    var entityId = await create('Reserved');
    var inviteId = await client.createEntityInvite(
      entityId: entityId,
      email: 'Bob@Test.local',
      fsUserAccess: TkCmsFsUserAccess()
        ..read.v = true
        ..write.v = true,
    );

    // Another verified user supplying the invited email is refused.
    var malloryId = await festenaoLocalAuthSignInVerified(
      context,
      'mallory@test.local',
    );
    await expectLater(
      client.acceptEntityInvite(
        entityId: entityId,
        inviteId: inviteId,
        email: 'bob@test.local',
      ),
      throwsA(isA<ApiException>()),
    );
    var firestore = context.fsDatabase.firestore;
    expect(
      (await context.fsDatabase.projectDb
              .fsEntityUserAccessRef(entityId, malloryId)
              .get(firestore))
          .exists,
      isFalse,
    );

    // The invited user, whatever email it supplies (none here).
    var bobId = await festenaoLocalAuthSignInVerified(
      context,
      'bob@test.local',
    );
    await client.acceptEntityInvite(entityId: entityId, inviteId: inviteId);
    var access = await context.fsDatabase.projectDb
        .fsEntityUserAccessRef(entityId, bobId)
        .get(firestore);
    expect(access.isWrite, isTrue);
  }, timeout: _timeout);
}

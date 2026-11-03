@TestOn('vm')
library;

import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/test/festenao_email_invite_test_runner.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_auth.dart';

/// The app whose projects have a create limit, served next to the server's.
const _limitedApp = 'limited_app';

/// A third app, limited too.
const _otherApp = 'other_limited_app';

/// The projects a user creates in the limited apps by default.
const _createLimit = 3;

/// The create limit of the entity handler and the users' plans (limits,
/// blocked users) on the in memory server.
void main() {
  late FestenaoTestServerContext context;
  late FestenaoProjectsServerApp serverApp;
  late FirebaseAuth auth;

  FestenaoApiService apiServiceOf(String app) => FestenaoApiService(
    callableApi: context.apiService.callableApi,
    httpClientFactory: httpClientFactoryMemory,
    app: app,
  );
  FestenaoFirestoreDatabase databaseOf(String app) =>
      context.fsDatabase.copyWithAppId(app);
  FestenaoApiFsEntityClient<FsProject> projectClientOf(String app) =>
      FestenaoApiFsEntityClient<FsProject>(
        apiService: apiServiceOf(app),
        entityAccess: databaseOf(app).projectDb,
      );
  late FestenaoApiFsEntityClient<FsProject> client;
  late FestenaoUserPlanApiClient planClient;

  Future<void> expectApiError(Future<void> Function() action, String code) =>
      expectLater(
        action(),
        throwsA(
          isA<ApiException>().having((e) => e.error?.code.v, 'code', code),
        ),
      );

  Future<String> create(
    String name, {
    FestenaoApiFsEntityClient<FsProject>? with_,
  }) async => (await (with_ ?? client).createEntity(
    entity: FsProject()..name.v = name,
  )).id;

  Future<void> setAppAdmin(String app, String userId) =>
      databaseOf(app).appDb.setEntityUserAccess(
        entityId: app,
        userId: userId,
        userAccess: TkCmsFsUserAccess()
          ..admin.v = true
          ..fixAccess(),
      );

  setUpAll(() async {
    context = await initFestenaoTestServerContextAllMemory();
    serverApp = context.ffContext.serverApp as FestenaoProjectsServerApp;
    for (var app in [_limitedApp, _otherApp]) {
      serverApp.addAppProjectHandler(
        app,
        options: FestenaoEntityHandlerOptions(createLimit: () => _createLimit),
      );
    }
    serverApp.userPlanHandler = FestenaoUserPlanHandler(
      apps: [_limitedApp, _otherApp],
      firestore: context.fsDatabase.firestore,
    );
    client = projectClientOf(_limitedApp);
    planClient = FestenaoUserPlanApiClient(
      apiService: apiServiceOf(_limitedApp),
    );
    auth = context.clientContext.firebaseAuth!;
  });
  tearDownAll(() async {
    await context.close();
  });

  test('the server app: no limit, served as before', () async {
    await festenaoLocalAuthSignInVerified(context, 'unlimited@test.local');
    for (var i = 1; i <= _createLimit + 1; i++) {
      await create('Projet $i', with_: context.projectApiClient);
    }
    // Not served without a create limit.
    await expectApiError(
      () => context.projectApiClient.getCreateLimit(),
      HttpsErrorCode.unimplemented,
    );
  });

  test('a limit, a deleted entity freeing its place', () async {
    var userId = await festenaoLocalAuthSignInVerified(
      context,
      'creator@test.local',
    );
    var db = databaseOf(_limitedApp);
    // Created directly, or shared with them: not counted.
    await db.projectDb.createEntity(
      userId: userId,
      entity: FsProject()..name.v = 'Avant',
    );
    var limit = await client.getCreateLimit();
    expect(limit.createLimit.v, _createLimit);
    expect(limit.userCreateLimit.v, isNull);
    expect(limit.createCount.v, 0);
    expect(limit.appAdmin.v, isFalse);
    expect(limit.canCreate, isTrue);

    var projectIds = [
      for (var i = 1; i <= _createLimit; i++) await create('Projet $i'),
    ];
    // In its app, its admin the user.
    var access = await db.projectDb
        .fsEntityUserAccessRef(projectIds.first, userId)
        .get(db.firestore);
    expect(access.isAdmin, isTrue);
    var creator = await festenaoEntityCreatorCollection(
      _limitedApp,
      'project',
    ).doc(projectIds.first).get(db.firestore);
    expect(creator.userId.v, userId);

    limit = await client.getCreateLimit();
    expect(limit.createCount.v, _createLimit);
    expect(limit.canCreate, isFalse);
    await expectApiError(
      () => create('Un de trop'),
      HttpsErrorCode.resourceExhausted,
    );

    await client.deleteEntity(entityId: projectIds.first);
    expect((await client.getCreateLimit()).createCount.v, _createLimit - 1);
    // Created deleted: alive, counted.
    var projectId = (await client.createEntity(
      entity: FsProject()
        ..name.v = 'Malin'
        ..deleted.v = true,
    )).id;
    var project = await db.projectDb.fsEntityRef(projectId).get(db.firestore);
    expect(project.deleted.v, isNull);
    await expectApiError(
      () => create('Un de trop'),
      HttpsErrorCode.resourceExhausted,
    );
  });

  test('counted per app', () async {
    await festenaoLocalAuthSignInVerified(context, 'two.apps@test.local');
    var otherClient = projectClientOf(_otherApp);
    for (var i = 1; i <= _createLimit; i++) {
      await create('Projet $i');
    }
    var projectId = await create('Ailleurs', with_: otherClient);
    var otherDb = databaseOf(_otherApp);
    expect(
      (await otherDb.projectDb.fsEntityRef(projectId).get(otherDb.firestore))
          .name
          .v,
      'Ailleurs',
    );
    expect((await otherClient.getCreateLimit()).createCount.v, 1);
    expect((await client.getCreateLimit()).createCount.v, _createLimit);
  });

  test('the plans: set by an app admin, none for an app admin', () async {
    var userId = await festenaoLocalAuthSignInVerified(
      context,
      'limited@test.local',
    );
    expect((await planClient.get()).createLimits.v, isNull);
    // Not an app admin: neither theirs nor anyone's.
    await expectApiError(
      () => planClient.set(
        FestenaoUserPlanSetApiQuery()
          ..userId.v = userId
          ..createLimits.v = {'project': 10},
      ),
      HttpsErrorCode.permissionDenied,
    );
    var adminId = await festenaoLocalAuthSignInVerified(
      context,
      'app.admin@test.local',
    );
    await expectApiError(
      () => planClient.get(userId: userId),
      HttpsErrorCode.permissionDenied,
    );
    await expectApiError(
      () => client.getCreateLimit(userId: userId),
      HttpsErrorCode.permissionDenied,
    );
    await setAppAdmin(_limitedApp, adminId);
    var adminLimit = await client.getCreateLimit();
    expect(adminLimit.appAdmin.v, isTrue);
    expect(adminLimit.createLimit.v, isNull);
    for (var i = 1; i <= _createLimit + 1; i++) {
      await create('Admin $i');
    }

    var plan = await planClient.set(
      FestenaoUserPlanSetApiQuery()
        ..userId.v = userId
        ..createLimits.v = {'project': 1},
    );
    expect(plan.createLimitOf('project'), 1);
    expect(plan.updatedBy.v, adminId);
    var limit = await client.getCreateLimit(userId: userId);
    expect(limit.createLimit.v, 1);
    expect(limit.userCreateLimit.v, 1);

    await festenaoLocalAuthSignInVerified(context, 'limited@test.local');
    await create('Le seul');
    await expectApiError(
      () => create('Un de trop'),
      HttpsErrorCode.resourceExhausted,
    );

    // Back to the default; a negative limit refused.
    await festenaoLocalAuthSignInVerified(context, 'app.admin@test.local');
    plan = await planClient.set(
      FestenaoUserPlanSetApiQuery()
        ..userId.v = userId
        ..createLimits.v = {'project': null},
    );
    expect(plan.createLimits.v, isNull);
    limit = await client.getCreateLimit(userId: userId);
    expect(limit.createLimit.v, _createLimit);
    expect(limit.createCount.v, 1);
    await expectApiError(
      () => planClient.set(
        FestenaoUserPlanSetApiQuery()
          ..userId.v = userId
          ..createLimits.v = {'project': -1},
      ),
      HttpsErrorCode.invalidArgument,
    );
  });

  test('a blocked user: their commands refused', () async {
    var userId = await festenaoLocalAuthSignInVerified(
      context,
      'blocked@test.local',
    );
    await create('Avant');
    var adminId = await festenaoLocalAuthSignInVerified(
      context,
      'blocking.admin@test.local',
    );
    await setAppAdmin(_limitedApp, adminId);
    var plan = await planClient.set(
      FestenaoUserPlanSetApiQuery()
        ..userId.v = userId
        ..blocked.v = true
        ..blockedReason.v = 'Spam',
    );
    expect(plan.blocked.v, isTrue);
    expect(plan.blockedReason.v, 'Spam');
    // The limits kept.
    plan = await planClient.set(
      FestenaoUserPlanSetApiQuery()
        ..userId.v = userId
        ..createLimits.v = {'project': 5},
    );
    expect(plan.blocked.v, isTrue);

    await festenaoLocalAuthSignInVerified(context, 'blocked@test.local');
    for (var action in <Future<void> Function()>[
      () => create('Bloqué'),
      () => client.getCreateLimit(),
      () => planClient.get(),
    ]) {
      await expectApiError(action, HttpsErrorCode.permissionDenied);
    }
    // Only in the apps of the plan handler.
    await create('Ailleurs', with_: context.projectApiClient);

    // An app admin is never blocked.
    await festenaoLocalAuthSignInVerified(context, 'blocking.admin@test.local');
    await planClient.set(
      FestenaoUserPlanSetApiQuery()
        ..userId.v = adminId
        ..blocked.v = true,
    );
    expect((await planClient.get()).blocked.v, isTrue);

    plan = await planClient.set(
      FestenaoUserPlanSetApiQuery()
        ..userId.v = userId
        ..blocked.v = false,
    );
    expect(plan.blocked.v, isNull);
    expect(plan.blockedReason.v, isNull);
    expect(plan.createLimitOf('project'), 5);
    await festenaoLocalAuthSignInVerified(context, 'blocked@test.local');
    await create('Débloqué');
  });

  test('signed in only', () async {
    await auth.signOut();
    await expectApiError(
      () => create('Anonyme'),
      HttpsErrorCode.unauthenticated,
    );
    await expectApiError(
      () => planClient.get(),
      HttpsErrorCode.unauthenticated,
    );
  });
}

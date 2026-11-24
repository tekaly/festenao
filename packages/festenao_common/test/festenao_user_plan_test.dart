@TestOn('vm')
library;

import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/festenao_slug.dart';
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
  late FestenaoUserPlanHandler userPlanHandler;

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
    serverApp.userPlanHandler = userPlanHandler = FestenaoUserPlanHandler(
      apps: [_limitedApp, _otherApp],
      firestore: context.fsDatabase.firestore,
      database: context.fsDatabase,
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

  test('the site plan: a public address counted, paid for more', () async {
    var userId = await festenaoLocalAuthSignInVerified(
      context,
      'site@test.local',
    );
    var db = databaseOf(_limitedApp);
    var first = await create('Festival un');
    var second = await create('Festival deux');
    var third = await create('Festival trois');

    var plan = await planClient.get();
    expect(plan.paid.v, isFalse);
    expect(plan.effectiveSlugLimit.v, 1);
    expect(plan.effectiveAds.v, isTrue);
    expect(plan.slugProjectCount.v, 0);
    expect(plan.canClaimSlug, isTrue);

    plan = await planClient.claimProjectSlug(
      projectId: first,
      slug: 'festival-un',
    );
    expect(plan.slugProjectCount.v, 1);
    expect(plan.canClaimSlug, isFalse);
    expect(await db.resolveProjectSlug('festival-un'), first);
    // Its address changed: no new place, the old one an alias.
    plan = await planClient.claimProjectSlug(
      projectId: first,
      slug: 'festival-un-2027',
    );
    expect(plan.slugProjectCount.v, 1);
    var project = await db.projectDb.fsEntityRef(first).get(db.firestore);
    expect(project.urlSlugs, ['festival-un-2027', 'festival-un']);
    expect(await db.resolveProjectSlug('festival-un'), first);

    await expectApiError(
      () =>
          planClient.claimProjectSlug(projectId: second, slug: 'festival-deux'),
      HttpsErrorCode.resourceExhausted,
    );
    expect(await db.resolveProjectSlug('festival-deux'), isNull);
    await expectApiError(
      () => planClient.claimProjectSlug(projectId: second, slug: 'a b'),
      HttpsErrorCode.invalidArgument,
    );
    // The usage is the server's: the client reads no count of its own.
    var usage = await userPlanHandler.usageOf(_limitedApp, userId);
    expect(usage.slugProjects.v, [first]);

    // Another user: not an admin of the project, a slug taken.
    await festenaoLocalAuthSignInVerified(context, 'site.other@test.local');
    var others = await create('Autre festival');
    await expectApiError(
      () => planClient.claimProjectSlug(projectId: first, slug: 'vole'),
      HttpsErrorCode.permissionDenied,
    );
    await expectApiError(
      () => planClient.claimProjectSlug(projectId: others, slug: 'festival-un'),
      HttpsErrorCode.alreadyExists,
    );
    // Nothing counted for a refused claim.
    expect((await planClient.get()).slugProjectCount.v, 0);

    // Paid by an app admin: more addresses, no ads.
    var adminId = await festenaoLocalAuthSignInVerified(
      context,
      'site.admin@test.local',
    );
    await setAppAdmin(_limitedApp, adminId);
    var paidUntil = DateTime.now().toUtc().add(const Duration(days: 365));
    plan = await planClient.set(
      FestenaoUserPlanSetApiQuery()
        ..userId.v = userId
        ..paidUntil.v = paidUntil.toIso8601String(),
    );
    expect(plan.paid.v, isTrue);
    expect(plan.inGrace.v, isFalse);
    expect(plan.effectiveSlugLimit.v, 10);
    expect(plan.effectiveAds.v, isFalse);
    expect(DateTime.parse(plan.paidUntil.v!), paidUntil);
    await expectApiError(
      () => planClient.set(
        FestenaoUserPlanSetApiQuery()
          ..userId.v = userId
          ..paidUntil.v = 'demain',
      ),
      HttpsErrorCode.invalidArgument,
    );

    await festenaoLocalAuthSignInVerified(context, 'site@test.local');
    plan = await planClient.claimProjectSlug(
      projectId: second,
      slug: 'festival-deux',
    );
    expect(plan.slugProjectCount.v, 2);

    // A payment past its grace: back to the free plan, the addresses kept,
    // none more.
    await userPlanHandler.recordPayment(
      _limitedApp,
      userId,
      paidUntil: DateTime.now().subtract(const Duration(days: 30)),
      subscriptionId: 'sub_test',
    );
    plan = await planClient.get();
    expect(plan.paid.v, isFalse);
    expect(plan.subscriptionId.v, 'sub_test');
    expect(plan.effectiveSlugLimit.v, 1);
    expect(plan.slugProjectCount.v, 2);
    expect(await db.resolveProjectSlug('festival-deux'), second);
    await expectApiError(
      () =>
          planClient.claimProjectSlug(projectId: third, slug: 'festival-trois'),
      HttpsErrorCode.resourceExhausted,
    );
    // Within the grace period: still paid.
    await userPlanHandler.recordPayment(
      _limitedApp,
      userId,
      paidUntil: DateTime.now().subtract(const Duration(days: 1)),
    );
    plan = await planClient.get();
    expect(plan.paid.v, isTrue);
    expect(plan.inGrace.v, isTrue);

    // Released: its place freed, its addresses gone, the project kept.
    plan = await planClient.releaseProjectSlug(projectId: second);
    expect(plan.slugProjectCount.v, 1);
    expect(await db.resolveProjectSlug('festival-deux'), isNull);
    project = await db.projectDb.fsEntityRef(second).get(db.firestore);
    expect(project.exists, isTrue);
    expect(project.urlSlugs, isEmpty);
    usage = await userPlanHandler.usageOf(_limitedApp, userId);
    expect(usage.slugProjects.v, [first]);
    // Released again: nothing changes.
    plan = await planClient.releaseProjectSlug(projectId: second);
    expect(plan.slugProjectCount.v, 1);
  });

  test('the site plan: granted, own limit and ads, app admin', () async {
    var userId = await festenaoLocalAuthSignInVerified(
      context,
      'granted@test.local',
    );
    var projects = [for (var i = 1; i <= 3; i++) await create('Fête $i')];
    var adminId = await festenaoLocalAuthSignInVerified(
      context,
      'granting.admin@test.local',
    );
    await setAppAdmin(_limitedApp, adminId);
    var plan = await planClient.set(
      FestenaoUserPlanSetApiQuery()
        ..userId.v = userId
        ..granted.v = true
        ..slugLimit.v = 2
        ..ads.v = true,
    );
    expect(plan.granted.v, isTrue);
    expect(plan.paid.v, isTrue);
    expect(plan.paidUntil.v, isNull);
    expect(plan.effectiveSlugLimit.v, 2);
    expect(plan.effectiveAds.v, isTrue);
    await expectApiError(
      () => planClient.set(
        FestenaoUserPlanSetApiQuery()
          ..userId.v = userId
          ..slugLimit.v = -1,
      ),
      HttpsErrorCode.invalidArgument,
    );
    // An app admin has no limit.
    expect((await planClient.get()).effectiveSlugLimit.v, isNull);

    await festenaoLocalAuthSignInVerified(context, 'granted@test.local');
    for (var i = 0; i < 2; i++) {
      await planClient.claimProjectSlug(
        projectId: projects[i],
        slug: 'fete-granted-$i',
      );
    }
    await expectApiError(
      () => planClient.claimProjectSlug(
        projectId: projects[2],
        slug: 'fete-granted-2',
      ),
      HttpsErrorCode.resourceExhausted,
    );

    // Back to the defaults: the free plan.
    await festenaoLocalAuthSignInVerified(context, 'granting.admin@test.local');
    plan = await planClient.set(
      FestenaoUserPlanSetApiQuery()
        ..userId.v = userId
        ..granted.v = false
        ..slugLimit.v = null
        ..ads.v = null,
    );
    expect(plan.granted.v, isNull);
    expect(plan.slugLimit.v, isNull);
    expect(plan.paid.v, isFalse);
    expect(plan.effectiveSlugLimit.v, 1);
    expect(plan.effectiveAds.v, isTrue);
    expect(plan.slugProjectCount.v, 2);
  });

  test('the site plan: a co-admin, the place of the claimer', () async {
    var ownerId = await festenaoLocalAuthSignInVerified(
      context,
      'owner@test.local',
    );
    var db = databaseOf(_limitedApp);
    var projectId = await create('Fête partagée');
    await planClient.claimProjectSlug(projectId: projectId, slug: 'co-fete');
    var coId = await festenaoLocalAuthSignInVerified(
      context,
      'co.admin@test.local',
    );
    await db.projectDb.setEntityUserAccess(
      entityId: projectId,
      userId: coId,
      userAccess: TkCmsFsUserAccess()
        ..admin.v = true
        ..fixAccess(),
    );
    // Changed by the co-admin: still the owner's place.
    var plan = await planClient.claimProjectSlug(
      projectId: projectId,
      slug: 'co-fete-2027',
    );
    expect(plan.slugProjectCount.v, 0);
    expect(
      (await userPlanHandler.usageOf(_limitedApp, ownerId)).slugProjects.v,
      [projectId],
    );
    var holder = await festenaoSlugProjectCollection(
      _limitedApp,
    ).doc(projectId).get(db.firestore);
    expect(holder.userId.v, ownerId);
    // Released by the co-admin: the owner's place freed.
    await planClient.releaseProjectSlug(projectId: projectId);
    expect(
      (await userPlanHandler.usageOf(_limitedApp, ownerId)).slugProjects.v,
      isNull,
    );
    holder = await festenaoSlugProjectCollection(
      _limitedApp,
    ).doc(projectId).get(db.firestore);
    expect(holder.exists, isFalse);
    // Claimed again: the co-admin's place now.
    plan = await planClient.claimProjectSlug(
      projectId: projectId,
      slug: 'co-fete',
    );
    expect(plan.slugProjectCount.v, 1);
  });

  test('the site plan: two claims at once, one place', () async {
    await festenaoLocalAuthSignInVerified(context, 'racer@test.local');
    var first = await create('Course 1');
    var second = await create('Course 2');
    var results = await Future.wait([
      for (var (index, projectId) in [first, second].indexed)
        planClient
            .claimProjectSlug(projectId: projectId, slug: 'course-$index')
            .then<Object?>((plan) => plan, onError: (Object e) => e),
    ]);
    expect(results.whereType<FestenaoUserPlanApiResult>(), hasLength(1));
    expect(results.whereType<ApiException>().map((e) => e.error?.code.v), [
      HttpsErrorCode.resourceExhausted,
    ]);
    expect((await planClient.get()).slugProjectCount.v, 1);
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
    await expectApiError(
      () => planClient.claimProjectSlug(projectId: 'p', slug: 'anonyme'),
      HttpsErrorCode.unauthenticated,
    );
  });

  group('festenaoSitePlanOf', () {
    var now = DateTime.utc(2026, 11, 24);
    FestenaoSitePlan planOf(
      FsFestenaoUserPlan plan, {
      DateTime? paidUntil,
      bool appAdmin = false,
    }) => festenaoSitePlanOf(
      plan,
      paidUntil: paidUntil,
      now: now,
      appAdmin: appAdmin,
    );

    test('free', () {
      var plan = planOf(FsFestenaoUserPlan());
      expect(plan.paid, isFalse);
      expect(plan.inGrace, isFalse);
      expect(plan.slugLimit, 1);
      expect(plan.ads, isTrue);
      expect(plan.canClaimSlug(0), isTrue);
      expect(plan.canClaimSlug(1), isFalse);
    });
    test('paid, grace, expired', () {
      var plan = planOf(
        FsFestenaoUserPlan(),
        paidUntil: now.add(const Duration(days: 1)),
      );
      expect(plan.paid, isTrue);
      expect(plan.inGrace, isFalse);
      expect(plan.slugLimit, 10);
      expect(plan.ads, isFalse);
      plan = planOf(FsFestenaoUserPlan(), paidUntil: now);
      expect(plan.paid, isTrue);
      expect(plan.inGrace, isTrue);
      plan = planOf(
        FsFestenaoUserPlan(),
        paidUntil: now.subtract(const Duration(days: 14)),
      );
      expect(plan.paid, isFalse);
      expect(plan.inGrace, isFalse);
      expect(plan.slugLimit, 1);
    });
    test('granted, own values, app admin', () {
      var plan = planOf(FsFestenaoUserPlan()..granted.v = true);
      expect(plan.paid, isTrue);
      expect(plan.inGrace, isFalse);
      plan = planOf(
        FsFestenaoUserPlan()
          ..slugLimit.v = 0
          ..ads.v = false,
      );
      expect(plan.slugLimit, 0);
      expect(plan.canClaimSlug(0), isFalse);
      expect(plan.ads, isFalse);
      plan = planOf(FsFestenaoUserPlan()..slugLimit.v = 2, appAdmin: true);
      expect(plan.slugLimit, isNull);
      expect(plan.canClaimSlug(100), isTrue);
    });
  });
}

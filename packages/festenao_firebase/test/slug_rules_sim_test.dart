import 'package:festenao_firebase/firestore_rules_test_runner.dart';
import 'package:test/test.dart';

/// The slug registry rules ([TkCmsEntityRules.addSlugRules]) of the api
/// context preset, on the simulator.
void main() {
  group('sim', () {
    runSlugRulesTests(
      (rules) => FirestoreRulesSimTestContext.create(rules: rules),
    );
    runSlugAppRightRulesTests(
      (rules) => FirestoreRulesSimTestContext.create(rules: rules),
    );
  });
}

/// The slug rules tests, on the context [builder] makes.
void runSlugRulesTests(
  Future<FirestoreRulesTestContext> Function(FirestoreRules rules) builder,
) {
  late FirestoreRulesTestContext ctx;
  var app = 'slug_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
  late String adminUid;
  late String otherUid;
  String accessPath(String projectId, String uid) =>
      'app/$app/access/project/entity_id/$projectId/user_access/$uid';

  setUpAll(() async {
    ctx = await builder(
      festenaoApiContextRules(options: const FestenaoRulesOptions(slugs: true)),
    );
    adminUid = await ctx.signInOrUp('admin@slug.test');
    otherUid = await ctx.signInOrUp('other@slug.test');
    await ctx.adminFirestore.doc('app/$app/project/p1').set({'name': 'P1'});
    await ctx.adminFirestore.doc(accessPath('p1', adminUid)).set({
      'admin': true,
      'write': true,
      'read': true,
    });
    await ctx.adminFirestore.doc('app/$app/slug/taken').set({
      'entityType': 'project',
      'entityId': 'p1',
    });
  });
  tearDownAll(() => ctx.close());

  Map<String, Object?> slugData(String entityId) => {
    'entityType': 'project',
    'entityId': entityId,
  };

  test('rules text', () {
    var text = festenaoApiContextRules(
      options: const FestenaoRulesOptions(slugs: true),
    ).toRulesText();
    expect(text, contains('match /{top}/{topId}/slug/{slug}'));
    expect(festenaoApiContextRules().toRulesText(), isNot(contains('/slug/')));
  });

  test('anyone gets, nobody lists', () async {
    await ctx.signOut();
    expect(
      (await ctx.firestore.doc('app/$app/slug/taken').get()).exists,
      isTrue,
    );
    await expectPermissionDenied(
      () => ctx.firestore.collection('app/$app/slug').get(),
    );
  });

  test('the admins of the entity write', () async {
    await ctx.signInOrUp('other@slug.test');
    expect(otherUid, isNotEmpty);
    await expectPermissionDenied(
      () => ctx.firestore.doc('app/$app/slug/mine').set(slugData('p1')),
    );
    await expectPermissionDenied(
      () => ctx.firestore.doc('app/$app/slug/taken').delete(),
    );
    await ctx.signInOrUp('admin@slug.test');
    await ctx.firestore.doc('app/$app/slug/mine').set(slugData('p1'));
    await ctx.firestore.doc('app/$app/slug/mine').set({
      ...slugData('p1'),
      'alias': true,
    });
    // Not to an entity it does not administer.
    await expectPermissionDenied(
      () => ctx.firestore.doc('app/$app/slug/mine').set(slugData('p2')),
    );
    await ctx.firestore.doc('app/$app/slug/mine').delete();
  });
}

/// The slug rules with the app right (`slugAppRight`), on the context
/// [builder] makes: the app admins write any slug and list them, the holders
/// of the app `slug` role write the slugs of the entities they administer,
/// the other entity admins none.
void runSlugAppRightRulesTests(
  Future<FirestoreRulesTestContext> Function(FirestoreRules rules) builder,
) {
  group('app right', () {
    late FirestoreRulesTestContext ctx;
    var app =
        'slug_right_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    const appAdminEmail = 'app-admin@slug.test';
    const sluggerEmail = 'slugger@slug.test';
    const entityAdminEmail = 'entity-admin@slug.test';
    String accessPath(String projectId, String uid) =>
        'app/$app/access/project/entity_id/$projectId/user_access/$uid';
    String appAccessPath(String uid) =>
        'access/app/entity_id/$app/user_access/$uid';
    Map<String, Object?> slugData(String entityId) => {
      'entityType': 'project',
      'entityId': entityId,
    };

    setUpAll(() async {
      ctx = await builder(
        festenaoApiContextRules(
          options: const FestenaoRulesOptions(slugs: true, slugAppRight: true),
        ),
      );
      var appAdminUid = await ctx.signInOrUp(appAdminEmail);
      var sluggerUid = await ctx.signInOrUp(sluggerEmail);
      var entityAdminUid = await ctx.signInOrUp(entityAdminEmail);
      var admin = ctx.adminFirestore;
      await admin.doc(appAccessPath(appAdminUid)).set({
        'admin': true,
        'write': true,
        'read': true,
      });
      await admin.doc(appAccessPath(sluggerUid)).set({
        'read': true,
        'role': 'user,$tkCmsRulesSlugRole',
      });
      await admin.doc(appAccessPath(entityAdminUid)).set({
        'read': true,
        'role': 'user',
      });
      for (var uid in [sluggerUid, entityAdminUid]) {
        await admin.doc(accessPath('p1', uid)).set({
          'admin': true,
          'write': true,
          'read': true,
        });
      }
      await admin.doc('app/$app/slug/taken').set(slugData('p2'));
    });
    tearDownAll(() => ctx.close());

    test('rules text', () {
      var text = festenaoApiContextRules(
        options: const FestenaoRulesOptions(slugs: true, slugAppRight: true),
      ).toRulesText();
      expect(text, contains('function subCanWriteSlug('));
      expect(text, contains("split(',').hasAny(['slug'])"));
      expect(text, contains('allow list: if signedIn() && subIsAppAdmin('));
    });

    test('an entity admin without the slug role writes none', () async {
      await ctx.signInOrUp(entityAdminEmail);
      await expectPermissionDenied(
        () => ctx.firestore.doc('app/$app/slug/admin-p1').set(slugData('p1')),
      );
      await expectPermissionDenied(
        () => ctx.firestore.collection('app/$app/slug').get(),
      );
      expect(
        (await ctx.firestore.doc('app/$app/slug/taken').get()).exists,
        isTrue,
      );
    });

    test('the slug role writes the slugs of its entities', () async {
      await ctx.signInOrUp(sluggerEmail);
      await ctx.firestore.doc('app/$app/slug/slugger-p1').set(slugData('p1'));
      await ctx.firestore.doc('app/$app/slug/slugger-p1').set({
        ...slugData('p1'),
        'alias': true,
      });
      // Not to an entity it does not administer.
      await expectPermissionDenied(
        () => ctx.firestore.doc('app/$app/slug/slugger-p2').set(slugData('p2')),
      );
      await expectPermissionDenied(
        () => ctx.firestore.doc('app/$app/slug/taken').delete(),
      );
      // No list.
      await expectPermissionDenied(
        () => ctx.firestore.collection('app/$app/slug').get(),
      );
      await ctx.firestore.doc('app/$app/slug/slugger-p1').delete();
    });

    test('an app admin writes any slug and lists them', () async {
      await ctx.signInOrUp(appAdminEmail);
      await ctx.firestore.doc('app/$app/slug/app-p2').set(slugData('p2'));
      var list = await ctx.firestore.collection('app/$app/slug').get();
      expect(list.docs.map((doc) => doc.ref.id).toSet(), {'app-p2', 'taken'});
      await ctx.firestore.doc('app/$app/slug/taken').delete();
      await ctx.firestore.doc('app/$app/slug/app-p2').delete();
    });

    test('signed out: get only', () async {
      await ctx.signOut();
      await expectPermissionDenied(
        () => ctx.firestore.collection('app/$app/slug').get(),
      );
      await expectPermissionDenied(
        () => ctx.firestore.doc('app/$app/slug/out').set(slugData('p1')),
      );
    });
  });
}

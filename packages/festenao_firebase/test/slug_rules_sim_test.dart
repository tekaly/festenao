import 'package:festenao_firebase/firestore_rules_test_runner.dart';
import 'package:test/test.dart';

/// The slug registry rules ([TkCmsEntityRules.addSlugRules]) of the api
/// context preset, on the simulator.
void main() {
  group('sim', () {
    runSlugRulesTests(
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

import 'dart:async';

import 'package:dev_test/test.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';

import '../festenao/festenao_rules_presets.dart';
import '../rules/rules_builder.dart';
import '../rules/rules_expression.dart';
import 'firestore_rules_test_context.dart';

/// True if [e] is a permission denied firestore exception.
bool isPermissionDeniedException(Object e) =>
    e is FirestoreException && e.code == FirestoreErrorCode.permissionDenied;

/// Expects [action] to fail with a permission denied error.
Future<void> expectPermissionDenied(
  Future<void> Function() action, {
  String? reason,
}) async {
  try {
    await action();
  } catch (e) {
    expect(
      isPermissionDeniedException(e),
      isTrue,
      reason: '$e ${reason ?? ''}',
    );
    return;
  }
  fail('should have been denied ${reason ?? ''}');
}

/// The rules of the festenao contexts, exercised the same way on the
/// simulator and on the emulator: every test seeds through the admin
/// firestore, acts through the rules enforced one as one or several users,
/// and checks what is allowed and what is denied.
///
/// A run of the emulator suite is the reference; the simulator suite must
/// pass identically.
void runFestenaoFirestoreRulesTests(
  FirestoreRulesTestContextBuilder contextBuilder, {
  FutureOr<void> Function(FirestoreRulesTestContext ctx, String preset)?
  setRules,
}) {
  late FirestoreRulesTestContext ctx;
  // The rules of a preset group, the preset itself unless overridden (to run
  // the suite on a hand written rules file for example).
  Future<void> usePreset(String preset) async {
    if (setRules != null) {
      await setRules(ctx, preset);
    } else {
      await ctx.setRules(festenaoRulesPresets[preset]!());
    }
  }

  var runId = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  var appId = 'rt_$runId';
  var emails = <String, String>{};

  /// The email of the test user [name] (unique per run, stable within it so
  /// that signing in again as [name] gives the same user).
  String newEmail(String name) =>
      emails[name] ??= '$name-$runId-${emails.length + 1}@rules.test';

  String projectPath(String projectId) => 'app/$appId/project/$projectId';
  String accessPath(String projectId, String uid) =>
      'app/$appId/access/project/entity_id/$projectId/user_access/$uid';
  String entityAccessPath(String projectId, String uid) =>
      'app/$appId/access/project/user_id/$uid/entity_access/$projectId';
  String publicAccessPath(String projectId) =>
      'app/$appId/access/project/entity_id/$projectId/public_access/public';

  Future<void> grant(
    String projectId,
    String uid, {
    bool admin = false,
    bool write = false,
    bool read = false,
  }) async {
    var access = {
      'admin': admin,
      'write': write || admin,
      'read': read || write || admin,
    };
    await ctx.adminFirestore.doc(accessPath(projectId, uid)).set(access);
    await ctx.adminFirestore.doc(entityAccessPath(projectId, uid)).set(access);
  }

  setUpAll(() async {
    ctx = await contextBuilder();
  });
  tearDownAll(() async {
    await ctx.close();
  });

  group('api_context', () {
    setUpAll(() async {
      await usePreset('api_context');
    });
    setUp(() async {
      await ctx.signOut();
    });

    test('entity access levels', () async {
      var projectId = 'levels';
      var strangerUid = await ctx.signInOrUp(newEmail('stranger'));
      await ctx.signOut();
      var adminUid = await ctx.signInOrUp(newEmail('admin'));
      await grant(projectId, adminUid, admin: true);
      var projectRef = ctx.firestore.doc(projectPath(projectId));
      var dataRef = ctx.firestore.doc('${projectPath(projectId)}/data/d1');
      var otherRef = ctx.firestore.doc('${projectPath(projectId)}/other/o1');

      // Admin: the entity document, its data, not other subcollections.
      await projectRef.set({'name': 'p'});
      expect((await projectRef.get()).data, {'name': 'p'});
      await dataRef.set({'name': 'd'});
      expect((await dataRef.get()).data, {'name': 'd'});
      await expectPermissionDenied(() => otherRef.set({'x': 1}));
      await expectPermissionDenied(() => otherRef.get());

      // Stranger: nothing.
      await ctx.signOut();
      await ctx.signInOrUp(newEmail('stranger2'));
      await expectPermissionDenied(() => projectRef.get());
      await expectPermissionDenied(() => dataRef.set({'name': 'x'}));
      expect(strangerUid, isNot(adminUid));

      // Signed out: nothing.
      await ctx.signOut();
      await expectPermissionDenied(() => projectRef.get());
      await expectPermissionDenied(() => dataRef.get());

      // Writer: data yes, entity document no.
      await grant(projectId, adminUid, write: true);
      await ctx.signInOrUp(newEmail('admin'));
      expect(ctx.auth.currentUser!.uid, adminUid);
      await expectPermissionDenied(() => projectRef.set({'name': 'p2'}));
      await expectPermissionDenied(() => projectRef.delete());
      await dataRef.set({'name': 'd2'});
      expect((await projectRef.get()).data, {'name': 'p'});

      // Reader: read only.
      await grant(projectId, adminUid, read: true);
      await expectPermissionDenied(() => dataRef.set({'name': 'd3'}));
      await expectPermissionDenied(() => dataRef.delete());
      expect((await dataRef.get()).data, {'name': 'd2'});
      expect((await projectRef.get()).exists, isTrue);

      // No access at all (explicit false).
      await grant(projectId, adminUid);
      await expectPermissionDenied(() => projectRef.get());
      await expectPermissionDenied(() => dataRef.get());

      // Access document deleted.
      await ctx.adminFirestore.doc(accessPath(projectId, adminUid)).delete();
      await expectPermissionDenied(() => projectRef.get());
    });

    test('access rows', () async {
      var projectId = 'rows';
      var memberUid = await ctx.signInOrUp(newEmail('member'));
      await ctx.signOut();
      var adminUid = await ctx.signInOrUp(newEmail('admin'));
      await grant(projectId, adminUid, admin: true);
      await grant(projectId, memberUid, read: true);

      // Admin reads and writes every access row.
      var memberAccessRef = ctx.firestore.doc(accessPath(projectId, memberUid));
      expect((await memberAccessRef.get()).data['read'], isTrue);
      await memberAccessRef.set({'admin': false, 'write': true, 'read': true});
      await ctx.firestore.doc(entityAccessPath(projectId, memberUid)).set({
        'admin': false,
        'write': true,
        'read': true,
      });
      // Admin own rows.
      expect(
        (await ctx.firestore.doc(accessPath(projectId, adminUid)).get()).exists,
        isTrue,
      );

      // Member: own user_id rows readable, entity side rows not, no write.
      await ctx.signOut();
      await ctx.signInOrUp(newEmail('member'));
      expect(ctx.auth.currentUser!.uid, memberUid);
      var ownEntityAccessRef = ctx.firestore.doc(
        entityAccessPath(projectId, memberUid),
      );
      expect((await ownEntityAccessRef.get()).data['write'], isTrue);
      expect(
        (await ctx.firestore
                .doc('app/$appId/access/project/user_id/$memberUid')
                .get())
            .exists,
        isFalse,
      );
      await expectPermissionDenied(() => memberAccessRef.get());
      await expectPermissionDenied(
        () => memberAccessRef.set({'admin': true, 'write': true, 'read': true}),
      );
      await expectPermissionDenied(
        () => ownEntityAccessRef.set({
          'admin': true,
          'write': true,
          'read': true,
        }),
      );
      await expectPermissionDenied(
        () => ctx.firestore.doc(entityAccessPath(projectId, adminUid)).get(),
      );
    });

    test('invite read', () async {
      var projectId = 'invite';
      var invitePath =
          'app/$appId/invite/project/invite_id/inv1/invite_entity/$projectId';
      await ctx.adminFirestore.doc(invitePath).set({'entityId': projectId});
      var inviteRef = ctx.firestore.doc(invitePath);
      await expectPermissionDenied(() => inviteRef.get());
      await ctx.signInOrUp(newEmail('invited'));
      expect((await inviteRef.get()).data, {'entityId': projectId});
      await expectPermissionDenied(() => inviteRef.set({'entityId': 'x'}));
      await expectPermissionDenied(() => inviteRef.delete());
    });

    test('user private data', () async {
      var otherUid = await ctx.signInOrUp(newEmail('other'));
      await ctx.signOut();
      var uid = await ctx.signInOrUp(newEmail('user'));
      String userPrvPath(String uid, [String? sub]) =>
          'app/$appId/user_prv/$uid${sub == null ? '' : '/$sub'}';
      var ownRootRef = ctx.firestore.doc(userPrvPath(uid));
      var ownDataRef = ctx.firestore.doc(userPrvPath(uid, 'data/d1'));
      var ownDeepRef = ctx.firestore.doc(userPrvPath(uid, 'data/d1/sub/s1'));
      var otherDataRef = ctx.firestore.doc(userPrvPath(otherUid, 'data/d1'));
      for (var ref in [ownRootRef, ownDataRef, ownDeepRef]) {
        await ref.set({'name': 'prv'});
        expect((await ref.get()).data, {'name': 'prv'}, reason: ref.path);
      }
      await expectPermissionDenied(() => otherDataRef.set({'name': 'nope'}));
      await expectPermissionDenied(() => otherDataRef.get());
      // Own list.
      expect(
        (await ctx.firestore.collection(userPrvPath(uid, 'data')).get()).docs,
        hasLength(1),
      );
      await expectPermissionDenied(
        () => ctx.firestore.collection(userPrvPath(otherUid, 'data')).get(),
      );
      await ctx.signOut();
      await expectPermissionDenied(() => ownDataRef.get());
      await expectPermissionDenied(() => ownDataRef.set({'name': 'nope'}));
      await ctx.signInOrUp(newEmail('user'));
      for (var ref in [ownDeepRef, ownDataRef, ownRootRef]) {
        await ref.delete();
      }
    });

    test('list', () async {
      var projectId = 'list';
      var readerUid = await ctx.signInOrUp(newEmail('reader'));
      await grant(projectId, readerUid, read: true);
      var dataPath = '${projectPath(projectId)}/data';
      await ctx.adminFirestore.doc('$dataPath/d1').set({'name': 'a'});
      await ctx.adminFirestore.doc('$dataPath/d2').set({'name': 'b'});

      var dataCollection = ctx.firestore.collection(dataPath);
      expect((await dataCollection.get()).docs, hasLength(2));
      expect(
        (await dataCollection.where('name', isEqualTo: 'b').get())
            .docs
            .single
            .ref
            .id,
        'd2',
      );
      // Own access index.
      var ownIndex = ctx.firestore.collection(
        'app/$appId/access/project/user_id/$readerUid/entity_access',
      );
      expect(
        (await ownIndex.get()).docs.map((d) => d.ref.id),
        contains(projectId),
      );
      // Listing the entities themselves: the entityId wildcard is unbound.
      await expectPermissionDenied(
        () => ctx.firestore.collection('app/$appId/project').get(),
      );

      await ctx.signOut();
      await ctx.signInOrUp(newEmail('stranger'));
      await expectPermissionDenied(() => dataCollection.get());
      await expectPermissionDenied(() => ownIndex.get());
      await ctx.signOut();
      await expectPermissionDenied(() => dataCollection.get());
    });

    test('batch and transaction', () async {
      var projectId = 'batch';
      var writerUid = await ctx.signInOrUp(newEmail('writer'));
      await grant(projectId, writerUid, write: true);
      await ctx.adminFirestore.doc(projectPath(projectId)).set({'name': 'p'});
      var dataPath = '${projectPath(projectId)}/data';

      var batch = ctx.firestore.batch();
      batch.set(ctx.firestore.doc('$dataPath/b1'), {'v': 1});
      batch.set(ctx.firestore.doc('$dataPath/b2'), {'v': 2});
      await batch.commit();
      expect((await ctx.adminFirestore.doc('$dataPath/b2').get()).data, {
        'v': 2,
      });

      // One denied write denies the whole batch.
      batch = ctx.firestore.batch();
      batch.set(ctx.firestore.doc('$dataPath/b3'), {'v': 3});
      batch.set(ctx.firestore.doc(projectPath(projectId)), {'name': 'nope'});
      await expectPermissionDenied(() => batch.commit());
      expect(
        (await ctx.adminFirestore.doc('$dataPath/b3').get()).exists,
        isFalse,
      );
      expect(
        (await ctx.adminFirestore.doc(projectPath(projectId)).get()).data,
        {'name': 'p'},
      );

      if (ctx.firestore.supportsTransaction) {
        await ctx.firestore.runTransaction((txn) async {
          var snapshot = await txn.get(ctx.firestore.doc('$dataPath/b1'));
          txn.set(ctx.firestore.doc('$dataPath/b1'), {
            'v': (snapshot.data['v'] as int) + 1,
          });
        });
        expect((await ctx.adminFirestore.doc('$dataPath/b1').get()).data, {
          'v': 2,
        });
        await expectPermissionDenied(
          () => ctx.firestore.runTransaction((txn) async {
            txn.set(ctx.firestore.doc(projectPath(projectId)), {'name': 'no'});
          }),
        );
      }
    });
  });

  group('no_api_context', () {
    setUpAll(() async {
      await usePreset('no_api_context');
    });
    setUp(() async {
      await ctx.signOut();
    });

    test('creator flow', () async {
      var projectId = 'created';
      var strangerUid = await ctx.signInOrUp(newEmail('stranger'));
      await ctx.signOut();
      var creatorUid = await ctx.signInOrUp(newEmail('creator'));
      var projectRef = ctx.firestore.doc(projectPath(projectId));

      // Naming someone else as creator is denied, naming oneself works.
      await expectPermissionDenied(
        () => projectRef.set({'creatorUserId': strangerUid, 'name': 'x'}),
      );
      await projectRef.set({'creatorUserId': creatorUid, 'name': 'created'});
      // No access document yet: no update.
      await expectPermissionDenied(() => projectRef.set({'name': 'updated'}));
      // The creator writes its own access documents.
      var access = {'admin': true, 'write': true, 'read': true};
      await ctx.firestore.doc(accessPath(projectId, creatorUid)).set(access);
      await ctx.firestore
          .doc(entityAccessPath(projectId, creatorUid))
          .set(access);
      // Now an admin.
      await projectRef.set({'name': 'updated'});
      await ctx.firestore.doc('${projectPath(projectId)}/data/d1').set({
        'v': 1,
      });

      // A stranger cannot grant itself access, but can get the document.
      await ctx.signOut();
      await ctx.signInOrUp(newEmail('stranger'));
      expect(ctx.auth.currentUser!.uid, strangerUid);
      await expectPermissionDenied(
        () => ctx.firestore.doc(accessPath(projectId, strangerUid)).set(access),
      );
      await expectPermissionDenied(
        () => ctx.firestore
            .doc(entityAccessPath(projectId, strangerUid))
            .set(access),
      );
      expect((await projectRef.get()).data['name'], 'updated');
      await expectPermissionDenied(
        () => ctx.firestore.collection('app/$appId/project').get(),
      );
      await expectPermissionDenied(
        () => ctx.firestore.doc('${projectPath(projectId)}/data/d1').get(),
      );
      // Signed out: no get either.
      await ctx.signOut();
      await expectPermissionDenied(() => projectRef.get());
    });

    test('public access (data only)', () async {
      var projectId = 'public';
      var adminUid = await ctx.signInOrUp(newEmail('admin'));
      await grant(projectId, adminUid, admin: true);
      var dataPath = '${projectPath(projectId)}/data/d1';
      await ctx.adminFirestore.doc(projectPath(projectId)).set({'name': 'p'});
      await ctx.adminFirestore.doc(dataPath).set({'v': 1});
      var flagRef = ctx.firestore.doc(publicAccessPath(projectId));

      // Anyone reads the flag, admins set it.
      expect((await flagRef.get()).exists, isFalse);
      await flagRef.set({'read': true});
      await ctx.signOut();
      expect((await flagRef.get()).data, {'read': true});
      // Anonymous: the data, not the entity document.
      expect((await ctx.firestore.doc(dataPath).get()).data, {'v': 1});
      expect(
        (await ctx.firestore.collection('${projectPath(projectId)}/data').get())
            .docs,
        hasLength(1),
      );
      await expectPermissionDenied(
        () => ctx.firestore.doc(projectPath(projectId)).get(),
      );
      await expectPermissionDenied(() => ctx.firestore.doc(dataPath).set({}));
      // A stranger cannot set the flag.
      await ctx.signInOrUp(newEmail('stranger'));
      await expectPermissionDenied(() => flagRef.set({'read': false}));
      expect((await ctx.firestore.doc(dataPath).get()).data, {'v': 1});
      // Flag off.
      await ctx.adminFirestore.doc(publicAccessPath(projectId)).set({
        'read': false,
      });
      await expectPermissionDenied(() => ctx.firestore.doc(dataPath).get());
    });

    test('public get', () async {
      // `public/get/{document=**}`: the documents live in collections under
      // `public/get`.
      await ctx.adminFirestore.doc('public/get/doc/doc1').set({'v': 1});
      var ref = ctx.firestore.doc('public/get/doc/doc1');
      expect((await ref.get()).data, {'v': 1});
      await expectPermissionDenied(
        () => ctx.firestore.collection('public/get/doc').get(),
      );
      await expectPermissionDenied(() => ref.set({'v': 2}));
      await expectPermissionDenied(
        () => ctx.firestore.doc('public/other/doc/doc1').get(),
      );
    });
  });

  group('full_api_context', () {
    setUpAll(() async {
      await usePreset('full_api_context');
    });
    setUp(() async {
      await ctx.signOut();
    });

    test('top level entity', () async {
      var topAppId = 'top_$runId';
      var uid = await ctx.signInOrUp(newEmail('app_writer'));
      await ctx.adminFirestore
          .doc('access/app/entity_id/$topAppId/user_access/$uid')
          .set({'admin': false, 'write': true, 'read': true});
      var appRef = ctx.firestore.doc('app/$topAppId');
      var subRef = ctx.firestore.doc('app/$topAppId/anything/x');
      await appRef.set({'name': 'app'});
      await subRef.set({'v': 1});
      expect((await appRef.get()).data, {'name': 'app'});
      expect((await subRef.get()).data, {'v': 1});
      // Own access row readable, not writable.
      var ownAccessRef = ctx.firestore.doc(
        'access/app/entity_id/$topAppId/user_access/$uid',
      );
      expect((await ownAccessRef.get()).data['write'], isTrue);
      await expectPermissionDenied(
        () => ownAccessRef.set({'admin': true, 'write': true, 'read': true}),
      );
      // Read access only is not enough at the top level (legacy rule).
      await ctx.adminFirestore
          .doc('access/app/entity_id/$topAppId/user_access/$uid')
          .set({'admin': false, 'write': false, 'read': true});
      await expectPermissionDenied(() => appRef.get());
      await ctx.signOut();
      await expectPermissionDenied(() => appRef.get());
    });

    test('standalone invite', () async {
      var projectId = 'invited';
      var invitedUid = await ctx.signInOrUp(newEmail('invited'));
      await ctx.signOut();
      var inviterUid = await ctx.signInOrUp(newEmail('inviter'));
      await ctx.signOut();
      var adminUid = await ctx.signInOrUp(newEmail('admin'));
      await grant(projectId, adminUid, admin: true);
      await ctx.adminFirestore.doc(projectPath(projectId)).set({'name': 'p'});
      var invitePath = 'app/$appId/invite/project/invite_id/inv1';
      var inviteEntityPath = '$invitePath/invite_entity/$projectId';
      var inviteEntity = {
        'inviteCode': 'code1',
        'entityId': projectId,
        'userAccess': {'admin': true, 'write': true, 'read': true},
      };
      // The entity admin creates invites for its entity, code or not.
      await ctx.firestore.doc(invitePath).set({
        'inviteCode': 'code1',
        'entityId': projectId,
      });
      await ctx.firestore.doc(inviteEntityPath).set(inviteEntity);
      await expectPermissionDenied(
        () => ctx.firestore.doc('$invitePath/invite_entity/other').set({
          ...inviteEntity,
          'entityId': 'other',
        }),
      );

      // The inviter is not an entity admin: it needs the invite code
      // capability.
      await ctx.signOut();
      await ctx.signInOrUp(newEmail('inviter'));
      var inviterInvitePath = 'app/$appId/invite/project/invite_id/inv2';
      await expectPermissionDenied(
        () => ctx.firestore
            .doc('$inviterInvitePath/invite_entity/$projectId')
            .set(inviteEntity),
      );
      await ctx.adminFirestore
          .doc(
            'app/$appId/access/project/user_id/$inviterUid/invite_access/code1',
          )
          .set({'admin': true, 'write': true, 'read': true});
      await expectPermissionDenied(
        () => ctx.firestore
            .doc('$inviterInvitePath/invite_entity/$projectId')
            .set({...inviteEntity, 'inviteCode': 'bad'}),
      );
      await ctx.firestore
          .doc('$inviterInvitePath/invite_entity/$projectId')
          .set(inviteEntity);

      // The invited user accepts by writing its own access document.
      await ctx.signOut();
      await ctx.signInOrUp(newEmail('invited'));
      expect(ctx.auth.currentUser!.uid, invitedUid);
      expect((await ctx.firestore.doc(inviteEntityPath).get()).exists, isTrue);
      var access = {
        'inviteId': 'inv1',
        'admin': true,
        'write': true,
        'read': true,
      };
      await expectPermissionDenied(
        () => ctx.firestore.doc(accessPath(projectId, invitedUid)).set({
          ...access,
          'inviteId': 'nope',
        }),
      );
      await ctx.firestore.doc(accessPath(projectId, invitedUid)).set(access);
      await ctx.firestore
          .doc(entityAccessPath(projectId, invitedUid))
          .set(access);
      // Now an admin of the project.
      await ctx.firestore.doc(projectPath(projectId)).set({'name': 'p2'});
      await ctx.firestore.doc(inviteEntityPath).delete();
    });

    test('public access (all)', () async {
      var projectId = 'public_all';
      await ctx.adminFirestore.doc(projectPath(projectId)).set({'name': 'p'});
      await ctx.adminFirestore.doc('${projectPath(projectId)}/data/d1').set({
        'v': 1,
      });
      var projectRef = ctx.firestore.doc(projectPath(projectId));
      await expectPermissionDenied(() => projectRef.get());
      await ctx.adminFirestore.doc(publicAccessPath(projectId)).set({
        'read': true,
      });
      expect((await projectRef.get()).data, {'name': 'p'});
      expect(
        (await ctx.firestore.doc('${projectPath(projectId)}/data/d1').get())
            .data,
        {'v': 1},
      );
      await expectPermissionDenied(() => projectRef.set({'name': 'x'}));
    });
  });

  group('custom claims', () {
    setUpAll(() async {
      var rules = FirestoreRules()..denyAll();
      rules.match('/claims_only/{docId}', (m) {
        m.allow(
          [RulesMethod.read, RulesMethod.write],
          requestAuth.isNotNull & requestAuthToken.get('role', '').eq('admin'),
        );
      });
      await ctx.setRules(rules);
    });

    test('role claim', () async {
      var email = newEmail('claimed');
      var uid = await ctx.signInOrUp(email);
      var ref = ctx.firestore.doc('claims_only/doc1');
      await expectPermissionDenied(() => ref.set({'v': 1}));
      await ctx.setCustomUserClaims(uid, {'role': 'admin'});
      // The claims land in the next token.
      await ctx.signOut();
      await ctx.signInOrUp(email);
      await ref.set({'v': 1});
      expect((await ref.get()).data, {'v': 1});
      await ctx.setCustomUserClaims(uid, null);
      await ctx.signOut();
      await ctx.signInOrUp(email);
      await expectPermissionDenied(() => ref.get());
      await ctx.signOut();
    });
  });
}

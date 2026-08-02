import 'dart:async';

import 'package:dev_test/test.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_support.dart';

import 'project_access_test_runner.dart';

/// Context for standalone project access test runner.
class ProjectStandaloneAccessTestContext {
  /// Auth service.
  final FirebaseAuth auth;

  /// Firestore service.
  final Firestore firestore;

  /// Constructor.
  ProjectStandaloneAccessTestContext({
    required this.auth,
    required this.firestore,
  });
}

/// Options for standalone project access test runner.
class ProjectStandaloneAccessTestOptions {
  /// Whether security rules are supported.
  final bool rulesSupported;

  /// Options for standalone project access test runner.
  const ProjectStandaloneAccessTestOptions({this.rulesSupported = true});
}

/// Standalone project access test runner mimicking project rules tests.
void projectStandaloneAccessTestRunner(
  FutureOr<ProjectStandaloneAccessTestContext> Function() contextBuilder, {
  bool rulesSupported = true,
  ProjectStandaloneAccessTestOptions? options,
}) {
  var effectiveRulesSupported = options?.rulesSupported ?? rulesSupported;
  late ProjectStandaloneAccessTestContext testContext;
  late FirebaseAuth auth;
  late Firestore firestore;

  setUp(() async {
    initTkCmsFsBuilders();
    testContext = await contextBuilder();
    auth = testContext.auth;
    firestore = testContext.firestore;
  });

  Future<void> expectPermissionError(Future<void> Function() action) async {
    if (effectiveRulesSupported) {
      try {
        await action();
        fail('should fail before');
      } catch (e) {
        expect(isExceptionPermissionError(e), isTrue, reason: '$e');
      }
    } else {
      await action();
    }
  }

  /// Sign in (or up) a given user, returns its user id.
  Future<String> signInEmail(String email) async {
    var userCredential = await auth.signInOrUpWithEmailAndPassword(
      email: email,
      password: 'test1234',
    );
    var userId = userCredential.user.uid;
    return userId;
  }

  /// Main (creator) user.
  Future<String> signIn() => signInEmail('admin@festenao-noff-test.local');

  /// Secondary (invited) user.
  Future<String> signInInvited() =>
      signInEmail('invited@festenao-noff-test.local');

  test('standalone helpers', () async {
    var appId = 'test_app';
    var projectId = 'test_festenao_access_standalone_helpers';

    final projectCollectionInfo = fsProjectCollectionInfo;
    var entityAccess =
        TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsProject>(
          entityCollectionInfo: projectCollectionInfo,
          firestore: firestore,
          rootDocument: fsAppRoot(appId),
        );
    var userId = await signIn();
    var entityRef = entityAccess.fsEntityRef(projectId);
    var userEntityAccessRef = entityAccess.fsUserEntityAccessRef(
      userId,
      projectId,
    );
    var existingEntity = await entityRef.get(firestore);
    if (existingEntity.exists) {
      // ignore: avoid_print
      print('$entityRef exists, deleting it');
      // Deleting needs admin access, a leftover project could have lost its
      // access document. The creator is always allowed to (re)create its own
      // access document.
      await entityAccess.standaloneSetUserAccess(
        entityId: projectId,
        userId: userId,
        access: TkCmsFsUserAccess()..grantAdminAccess(),
      );
      await entityAccess.standaloneDeleteAndPurge(
        entityId: projectId,
        userId: userId,
      );
    }
    var userEntityAccess = await userEntityAccessRef.get(firestore);
    expect(userEntityAccess.exists, isFalse);
    var entity = entityRef.cv()..name.v = 'test';
    await entityAccess.standaloneCreateEntity(
      entity: entity,
      userId: userId,
      entityId: projectId,
    );

    entity = await entityRef.get(firestore);
    expect(entity.exists, isTrue);
    userEntityAccess = await userEntityAccessRef.get(firestore);
    expect(userEntityAccess.exists, isTrue);

    // Rewrite the entity
    entity.creatorUserId.v = null;
    await entityRef.set(firestore, entity);

    // Write some data
    await firestore.collection('${entityRef.path}/data').doc('test_data').set({
      'name': 'test_data',
    });
    await expectPermissionError(() async {
      await firestore
          .collection('${entityRef.path}/other_than_data')
          .doc('test_data')
          .get();
    });

    try {
      await entityAccess.standaloneCreateEntity(
        entity: entity,
        userId: userId,
        entityId: projectId,
      );
      fail('should fail');
    } catch (e) {
      // ignore: avoid_print
      print('expected error recreating $e');
      expect(e, isNot(isA<TestFailure>()));
    }

    userEntityAccess = await userEntityAccessRef.get(firestore);
    expect(userEntityAccess.exists, isTrue);
    expect(userEntityAccess.admin.v, isTrue);

    await entityAccess.standaloneDeleteAndPurge(
      entityId: projectId,
      userId: userId,
    );
    existingEntity = await entityRef.get(firestore);
    expect(existingEntity.exists, isFalse);
    userEntityAccess = await userEntityAccessRef.get(firestore);
    expect(userEntityAccess.exists, isFalse);
  });

  test('standalone invited user access', () async {
    var appId = 'test_app';
    var projectId = 'test_festenao_access_standalone_invited';

    final projectCollectionInfo = fsProjectCollectionInfo;
    var entityAccess =
        TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsProject>(
          entityCollectionInfo: projectCollectionInfo,
          firestore: firestore,
          rootDocument: fsAppRoot(appId),
        );
    var entityRef = entityAccess.fsEntityRef(projectId);
    var dataRef = firestore.doc('${entityRef.path}/data/test_data');

    // Sign in the invited user once to get its user id.
    var invitedUserId = await signInInvited();
    await auth.signOut();

    var userId = await signIn();

    var existingEntity = await entityRef.get(firestore);
    if (existingEntity.exists) {
      // ignore: avoid_print
      print('$entityRef exists, deleting it');
      // Deleting needs admin access, a leftover project could have lost its
      // access document. The creator is always allowed to (re)create its own
      // access document.
      await entityAccess.standaloneSetUserAccess(
        entityId: projectId,
        userId: userId,
        access: TkCmsFsUserAccess()..grantAdminAccess(),
      );
      await entityAccess.standaloneDeleteAndPurge(
        entityId: projectId,
        userId: userId,
      );
    }

    await entityAccess.standaloneCreateEntity(
      entity: entityRef.cv()..name.v = 'test',
      userId: userId,
      entityId: projectId,
    );

    /// Set the invited user access as the creator, then sign the invited
    /// user back in. Only the creator/admin can change the access rights.
    Future<void> setInvitedUserAccess(TkCmsFsUserAccess? access) async {
      await auth.signOut();
      await signIn();
      await entityAccess.standaloneSetUserAccess(
        entityId: projectId,
        userId: invitedUserId,
        access: access,
      );
      await auth.signOut();
      await signInInvited();
    }

    /// Write the root entity document (keeping the creator id).
    Future<void> writeRootEntity(String name) async {
      await firestore.cvSet(
        entityRef.cv()
          ..name.v = name
          ..creatorUserId.v = userId,
      );
    }

    // Admin access: the invited user can write the root entity document.
    await setInvitedUserAccess(TkCmsFsUserAccess()..grantAdminAccess());

    var invitedAccess = await entityAccess
        .fsUserEntityAccessRef(invitedUserId, projectId)
        .get(firestore);
    expect(invitedAccess.exists, isTrue);
    expect(invitedAccess.admin.v, isTrue);

    await writeRootEntity('admin_write');
    await dataRef.set({'name': 'admin_data'});
    await dataRef.get();

    // Write only access: the root entity document needs admin access.
    await setInvitedUserAccess(
      (TkCmsFsUserAccess()..write.v = true)..fixAccess(),
    );

    await expectPermissionError(() async {
      await writeRootEntity('write_only_write');
    });
    // But the `data` sub collection is still writable.
    await dataRef.set({'name': 'write_only_data'});
    await dataRef.get();

    // Read only access: nothing is writable anymore.
    await setInvitedUserAccess(
      (TkCmsFsUserAccess()..read.v = true)..fixAccess(),
    );

    await expectPermissionError(() async {
      await writeRootEntity('read_only_write');
    });
    await expectPermissionError(() async {
      await dataRef.set({'name': 'read_only_data'});
    });
    // But reading is still allowed.
    await dataRef.get();

    // No access: reading the entity data is not allowed anymore.
    await setInvitedUserAccess(TkCmsFsUserAccess()..fixAccess());

    await expectPermissionError(() async {
      await dataRef.get();
    });

    // A null access deletes both access documents.
    await setInvitedUserAccess(null);

    invitedAccess = await entityAccess
        .fsUserEntityAccessRef(invitedUserId, projectId)
        .get(firestore);
    expect(invitedAccess.exists, isFalse);
    invitedAccess = await entityAccess
        .fsEntityUserAccessRef(projectId, invitedUserId)
        .get(firestore);
    expect(invitedAccess.exists, isFalse);

    await expectPermissionError(() async {
      await dataRef.get();
    });

    await auth.signOut();
    await signIn();
    await entityAccess.standaloneDeleteAndPurge(
      entityId: projectId,
      userId: userId,
    );
  });

  test('standalone public access', () async {
    var appId = 'test_app';
    var projectId = 'test_festenao_access_standalone_public';

    final projectCollectionInfo = fsProjectCollectionInfo;
    var entityAccess =
        TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsProject>(
          entityCollectionInfo: projectCollectionInfo,
          firestore: firestore,
          rootDocument: fsAppRoot(appId),
        );
    var entityRef = entityAccess.fsEntityRef(projectId);
    var dataRef = firestore.doc('${entityRef.path}/data/test_data');
    var publicAccessRef = entityAccess.fsEntityPublicAccessRef(projectId);

    var userId = await signIn();

    var existingEntity = await entityRef.get(firestore);
    if (existingEntity.exists) {
      // ignore: avoid_print
      print('$entityRef exists, deleting it');
      await entityAccess.standaloneSetUserAccess(
        entityId: projectId,
        userId: userId,
        access: TkCmsFsUserAccess()..grantAdminAccess(),
      );
      await entityAccess.standaloneSetPublicAccess(
        entityId: projectId,
        access: null,
      );
      await entityAccess.standaloneDeleteAndPurge(
        entityId: projectId,
        userId: userId,
      );
    }

    await entityAccess.standaloneCreateEntity(
      entity: entityRef.cv()..name.v = 'test',
      userId: userId,
      entityId: projectId,
    );
    await dataRef.set({'name': 'test_data'});

    await auth.signOut();

    // The public access document is readable by anyone, it is not set yet.
    var publicAccess = await publicAccessRef.get(firestore);
    expect(publicAccess.exists, isFalse);

    // Without public access, data cannot be read without signing in.
    await expectPermissionError(() async {
      await dataRef.get();
    });

    // Setting public access requires admin access.
    await expectPermissionError(() async {
      await entityAccess.standaloneSetPublicAccess(
        entityId: projectId,
        access: TkCmsFsPublicAccess()..read.v = true,
      );
    });

    await signIn();
    await entityAccess.standaloneSetPublicAccess(
      entityId: projectId,
      access: TkCmsFsPublicAccess()..read.v = true,
    );
    await auth.signOut();

    publicAccess = await publicAccessRef.get(firestore);
    expect(publicAccess.exists, isTrue);
    expect(publicAccess.read.v, isTrue);

    // Data can now be read without signing in.
    var dataSnapshot = await dataRef.get();
    expect(dataSnapshot.exists, isTrue);
    expect(dataSnapshot.data['name'], 'test_data');

    // But the root entity document is still not readable.
    await expectPermissionError(() async {
      await entityRef.get(firestore);
    });
    // And data is not writable.
    await expectPermissionError(() async {
      await dataRef.set({'name': 'public_write'});
    });

    // Delete the public access.
    await signIn();
    await entityAccess.standaloneSetPublicAccess(
      entityId: projectId,
      access: null,
    );
    await auth.signOut();

    publicAccess = await publicAccessRef.get(firestore);
    expect(publicAccess.exists, isFalse);

    // Data cannot be read anymore without signing in.
    await expectPermissionError(() async {
      await dataRef.get();
    });

    await signIn();
    await entityAccess.standaloneDeleteAndPurge(
      entityId: projectId,
      userId: userId,
    );
  });

  test('standalone user private data', () async {
    var appId = 'test_app';

    // Sign in the other user once to get its user id.
    var otherUserId = await signInInvited();

    var userId = await signIn();

    String userPrvPath(String userId, [String? subPath]) =>
        'app/$appId/user_prv/$userId${subPath == null ? '' : '/$subPath'}';

    // The user private root document itself (`{document=**}` also matches
    // an empty sub path).
    var ownRootRef = firestore.doc(userPrvPath(userId));
    // A document in a sub collection.
    var ownDataRef = firestore.doc(userPrvPath(userId, 'data/test_data'));
    // A deeper document (recursive wildcard).
    var ownDeepRef = firestore.doc(
      userPrvPath(userId, 'data/test_data/sub/deep_data'),
    );
    // Another user private data.
    var otherDataRef = firestore.doc(
      userPrvPath(otherUserId, 'data/test_data'),
    );

    // A signed in user can write and read its own private data, at any depth.
    for (var ref in [ownRootRef, ownDataRef, ownDeepRef]) {
      await ref.set({'name': 'test_user_prv'});
      var snapshot = await ref.get();
      expect(snapshot.exists, isTrue, reason: ref.path);
      expect(snapshot.data['name'], 'test_user_prv', reason: ref.path);
    }

    // But not another user private data.
    await expectPermissionError(() async {
      await otherDataRef.set({'name': 'nope'});
    });
    await expectPermissionError(() async {
      await otherDataRef.get();
    });

    await auth.signOut();

    // Signed out, nothing is readable nor writable.
    await expectPermissionError(() async {
      await ownDataRef.get();
    });
    await expectPermissionError(() async {
      await ownDataRef.set({'name': 'nope'});
    });

    // The other user can access its own private data, not ours.
    await signInInvited();
    await otherDataRef.set({'name': 'test_user_prv_other'});
    expect((await otherDataRef.get()).exists, isTrue);
    await expectPermissionError(() async {
      await ownDataRef.get();
    });

    // Cleanup, each user deletes its own private data.
    await otherDataRef.delete();
    await auth.signOut();
    await signIn();
    for (var ref in [ownDeepRef, ownDataRef, ownRootRef]) {
      await ref.delete();
    }
  });

  group('standalone project access runner', () {
    test('standalone project access', () async {
      var appId = 'test_app';
      var projectId2 = 'test_festenao_access_standalone';

      final projectCollectionInfo = fsProjectCollectionInfo;
      var entityAccess =
          TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsProject>(
            entityCollectionInfo: projectCollectionInfo,
            firestore: firestore,
            rootDocument: fsAppRoot(appId),
          );

      var userId = await signIn();

      var accessRef = entityAccess.fsEntityUserAccessRef(projectId2, userId);
      var entityRef = entityAccess.fsEntityRef(projectId2);

      var entity = await entityRef.get(firestore);
      if (entity.exists) {
        // ignore: avoid_print
        print('$entityRef exists. TODO delete project and access if possible');
        return;
      }
      // User cannot create the project without creatorUserId
      await expectPermissionError(() async {
        await firestore.cvSet(entityRef.cv()..name.v = 'test');
      });

      // It can create it with a userId
      await firestore.cvSet(
        entityRef.cv()
          ..name.v = 'test'
          ..creatorUserId.v = userId,
      );

      // But cannot write it yet without access grant
      await expectPermissionError(() async {
        await firestore.cvSet(
          entityRef.cv()
            ..name.v = 'test'
            ..creatorUserId.v = userId,
        );
      });

      // But it can get it: any signed in user is allowed to get the root
      // entity document.
      await entityRef.get(firestore);

      // User can write access (allowed as the project creator)
      await entityAccess.standaloneSetUserAccess(
        entityId: projectId2,
        userId: userId,
        access: TkCmsFsUserAccess()..grantAdminAccess(),
      );

      // Admin access allows writing the root entity document
      await firestore.cvSet(
        entityRef.cv()
          ..name.v = 'test2'
          ..creatorUserId.v = userId,
      );
      await entityRef.get(firestore);

      // Remove admin access, keep write access (last access change, doing
      // this requires admin access).
      await entityAccess.standaloneSetUserAccess(
        entityId: projectId2,
        userId: userId,
        access: (TkCmsFsUserAccess()..write.v = true)..fixAccess(),
      );

      // Write access is not enough to write the root entity document, the
      // rules require admin access on
      // `/{top}/{topId}/{entity}/{entityId}`.
      await expectPermissionError(() async {
        await firestore.cvSet(
          entityRef.cv()
            ..name.v = 'test3'
            ..creatorUserId.v = userId,
        );
      });

      // ...but write access does allow writing in the entity `data` sub
      // collection.
      await firestore.doc('${entityRef.path}/data/test_data').set({
        'name': 'test_data',
      });

      // Write access is not enough to change access either.
      await expectPermissionError(() async {
        await firestore.cvSet(accessRef.cv()..grantAdminAccess());
      });

      await auth.signOut();

      // Cannot read
      await expectPermissionError(() async {
        await entityRef.get(firestore);
      });
    });

    test('creatorUserId sub entity access', () async {
      var appId = 'test_app';
      var projectId2 = 'test_creator_project';
      var itemId = 'test_item';

      var creatorCredential = await auth.signInOrUpWithEmailAndPassword(
        email: 'creator@festenao-noff-test.local',
        password: 'test1234',
      );
      var creatorUserId = creatorCredential.user.uid;
      var entityRef = firestore.doc('app/$appId/project/$projectId2');

      if ((await entityRef.get()).exists) {
        // ignore: avoid_print
        print('$entityRef exists. TODO delete project and access if possible');
        return;
      }
      await entityRef.set({
        'name': 'test project',
        'creatorUserId': creatorUserId,
      });

      await expectPermissionError(() async {
        // Only data is supported here since 2026-08-01
        var itemRef = firestore.doc(
          'app/$appId/project/$projectId2/data/$itemId',
        );
        await itemRef.set({'name': 'test item'});
      });

      await auth.signOut();

      await auth.signInOrUpWithEmailAndPassword(
        email: 'stranger@festenao-noff-test.local',
        password: 'test1234',
      );

      await expectPermissionError(() async {
        await firestore
            .doc('app/$appId/project/$projectId2/item/other_item')
            .set({'name': 'nope'});
      });

      await auth.signOut();
    });
  });
}

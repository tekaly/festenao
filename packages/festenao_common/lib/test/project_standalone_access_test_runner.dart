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

  Future<String> signIn() async {
    var userCredential = await auth.signInOrUpWithEmailAndPassword(
      email: 'admin@festenao-noff-test.local',
      password: 'test1234',
    );
    var userId = userCredential.user.uid;
    return userId;
  }

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
    var entity = entityRef.cv()..name.v = 'test';
    await entityAccess.standaloneCreateEntity(
      entity: entity,
      userId: userId,
      entityId: projectId,
    );

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

      // Not read it
      await expectPermissionError(() async {
        await entityRef.get(firestore);
      });

      // User can write access
      await firestore.cvSet(accessRef.cv()..grantAdminAccess());

      // Remove admin access
      await firestore.cvSet((accessRef.cv()..write.v = true)..fixAccess());
      // Can still write
      await firestore.cvSet(
        entityRef.cv()
          ..name.v = 'test2'
          ..creatorUserId.v = userId,
      );
      await entityRef.get(firestore);

      // Remove write access
      await firestore.cvSet((accessRef.cv()..read.v = true)..fixAccess());
      // Cannot write
      await expectPermissionError(() async {
        await firestore.cvSet(
          entityRef.cv()
            ..name.v = 'test3'
            ..creatorUserId.v = userId,
        );
      });

      // Remove read access
      await firestore.cvSet((accessRef.cv()..read.v = false)..fixAccess());
      // Cannot read
      await expectPermissionError(() async {
        await entityRef.get(firestore);
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

      await firestore.doc('app/$appId/project/$projectId2').set({
        'name': 'test project',
        'creatorUserId': creatorUserId,
      });

      var itemRef = firestore.doc(
        'app/$appId/project/$projectId2/item/$itemId',
      );
      await itemRef.set({'name': 'test item'});

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

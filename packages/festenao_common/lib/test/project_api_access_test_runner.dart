import 'package:dev_test/test.dart';
import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/api/festenao_api_fs_entity_client.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_support.dart';

import 'festenao_test_server_test_runner.dart';
import 'project_access_test_runner.dart' show isExceptionPermissionError;

/// Options for the project api access test runners.
class ProjectApiAccessTestOptions {
  /// Whether firestore security rules are enforced by the deployment under
  /// test.
  ///
  /// `false` for an in memory (or otherwise ruleless) firestore: every direct
  /// firestore access the runners expect to be refused is then expected to go
  /// through instead, only the api (cloud function) part is really tested.
  final bool rulesSupported;

  /// Options for the project api access test runners.
  const ProjectApiAccessTestOptions({this.rulesSupported = true});
}

/// Check access unsing standard entity api
void appProjectAccessApiTestRunner(
  Future<FestenaoTestClientContext> Function() contextBuilder, {
  ProjectApiAccessTestOptions? options,
}) {
  var rulesSupported =
      (options ?? const ProjectApiAccessTestOptions()).rulesSupported;
  late FestenaoTestClientContext testContext;
  late FirebaseAuth auth;
  late final firestore = testContext.firestore!;

  /// Runs [action], expecting the rules to refuse it, unless the deployment
  /// under test has no rules at all (see [ProjectApiAccessTestOptions]).
  Future<void> expectPermissionError(Future<void> Function() action) async {
    if (!rulesSupported) {
      await action();
      return;
    }
    try {
      await action();
      fail('should fail');
    } catch (e) {
      expect(isExceptionPermissionError(e), isTrue, reason: '$e');
    }
  }

  setUp(() async {
    initFestenaoFsEntityApiBuilders<TkCmsFsProject>();
    testContext = await contextBuilder();
    auth = testContext.firebaseAuth!;
    testContext.apiService.httpsApiUri!;
  });

  test('admin can write, unrelated user cannot', () async {
    var credential = const TkCmsEmailPasswordCredentials(
      email: 'admin@festenao-dartff-test.local',
      password: 'test1234',
    );
    // Sign in the future app admin.
    await auth.signInOrUpWithEmailAndPassword(
      email: credential.email,
      password: credential.password,
    );
    expect(auth.currentUser, isNotNull);

    // Bootstrap the "app" (top) entity and grant this user admin access to
    // it, using the cloud function's entity create command: this runs
    // through the admin SDK server side, which bypasses security rules --
    // the only way to create the very first admin for an entity.
    initTkCmsFsBuilders();

    var appId = testContext.apiService.app;
    // ignore: unused_local_variable
    var userId = auth.currentUser!.uid;

    /// Project collection info.
    final projectCollectionInfo = fsProjectCollectionInfo;
    var entityAccess =
        TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsProject>(
          entityCollectionInfo: projectCollectionInfo,
          firestore: firestore, // Not used for access
          rootDocument: fsAppRoot(appId),
        );
    var appApiClient = FestenaoApiFsEntityClient<TkCmsFsProject>(
      apiService: testContext.apiService,
      entityAccess: entityAccess,
    );

    var entity = await appApiClient.createEntity(entity: TkCmsFsProject());
    expect(entity.path, 'app/$appId/project/${entity.id}');
    var projectId = entity.id;

    // print('$appId: $appId');
    // print('projectId: $projectId');
    // print('userId: $userId');
    var docRef = firestore.doc('app/$appId/project/$projectId/data/sub');
    await docRef.set({'probe': 'admin-write-ok'});

    var snapshot = await docRef.get();
    var data = snapshot.data;
    expect(data, {'probe': 'admin-write-ok'});

    // A different, unrelated user has no access grant on this entity: a
    // direct Firestore write must be rejected by the security rules.
    await auth.signOut();
    expect(auth.currentUser, isNull);
    await auth.signInOrUpWithEmailAndPassword(
      email: 'stranger@festenao-dartff-test.local',
      password: 'test1234',
    );
    expect(auth.currentUser, isNotNull);
    await expectPermissionError(() async {
      await docRef.set({'probe': 'stranger-write'});
    });
    await expectPermissionError(() async {
      await docRef.get();
    });

    // Sign in the future app admin.
    await auth.signInOrUpWithEmailAndPassword(
      email: credential.email,
      password: credential.password,
    );
    await docRef.get();
    await appApiClient.deleteEntity(entityId: entity.id);
    await appApiClient.purgeEntity(entityId: entity.id);
  });
}

/// Checks whether a project can be created straight from the client, by a user
/// naming itself as its `creatorUserId`.
///
/// This is what `projectStandaloneAccessTestRunner` relies on throughout: with
/// no backend, the rules let a signed in user create a top level entity as long
/// as it carries a `creatorUserId` field matching the requester (see the
/// "Project Creator (standalone)" block of the `festenao_firebase_no_api_context`
/// rules), and that self-declared creator is then what grants it its first
/// access document.
///
/// An api deployment must *not* allow that: creating a project goes through the
/// entity create cloud function, which runs the admin sdk server side, and the
/// rules only ever grant a client what an access document already says (see the
/// `festenao_firebase_api_context` rules, which have no creator block at all).
/// Letting a client create a project by simply claiming to be its creator would
/// hand it an admin grant on an entity the server never validated.
///
/// [creatorUserIdCreateSupported] says which of the two rule sets the
/// deployment under test carries: `false` (the default, an api deployment)
/// expects every creation below to be refused, `true` (a no api deployment)
/// expects them to go through.
///
/// A deployment with no rules at all (an in memory firestore, see
/// [ProjectApiAccessTestOptions.rulesSupported]) refuses nothing, so it always
/// behaves as if [creatorUserIdCreateSupported] was `true`.
void appProjectCreatorUserIdApiTestRunner(
  Future<FestenaoTestClientContext> Function() contextBuilder, {
  bool creatorUserIdCreateSupported = false,
  ProjectApiAccessTestOptions? options,
}) {
  var rulesSupported =
      (options ?? const ProjectApiAccessTestOptions()).rulesSupported;
  // With no rules, nothing is ever refused.
  var effectiveCreatorUserIdCreateSupported =
      creatorUserIdCreateSupported || !rulesSupported;
  late FestenaoTestClientContext testContext;
  late FirebaseAuth auth;
  late final firestore = testContext.firestore!;

  setUp(() async {
    initTkCmsFsBuilders();
    initFestenaoFsEntityApiBuilders<TkCmsFsProject>();
    testContext = await contextBuilder();
    auth = testContext.firebaseAuth!;
    testContext.apiService.httpsApiUri!;
  });

  /// Runs [action], expecting the rules to refuse it whatever the deployment:
  /// no rule set lets a client create a project it does not name itself the
  /// creator of.
  Future<void> expectPermissionError(Future<void> Function() action) async {
    if (!rulesSupported) {
      await action();
      return;
    }
    try {
      await action();
      fail('should fail');
    } catch (e) {
      expect(isExceptionPermissionError(e), isTrue, reason: '$e');
    }
  }

  /// Runs [action], a creation naming the signed in user as `creatorUserId`:
  /// refused here unless the deployment carries the standalone creator rules,
  /// see [creatorUserIdCreateSupported].
  Future<void> expectCreatorPermissionError(
    Future<void> Function() action,
  ) async {
    if (effectiveCreatorUserIdCreateSupported) {
      await action();
      return;
    }
    await expectPermissionError(action);
  }

  /// Signs a user in that holds no access grant on any entity: the whole point
  /// is what the rules let it do on its own.
  Future<String> signInCreator() async {
    var userCredential = await auth.signInOrUpWithEmailAndPassword(
      email: 'creator@festenao-dartff-test.local',
      password: 'test1234',
    );
    return userCredential.user.uid;
  }

  TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsProject> projectAccess() =>
      TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsProject>(
        entityCollectionInfo: fsProjectCollectionInfo,
        firestore: firestore,
        rootDocument: fsAppRoot(testContext.apiService.app),
      );

  group('project creatorUserId', () {
    test('creating a project naming itself the creator', () async {
      var projectId = 'test_festenao_api_creator_project';
      var entityAccess = projectAccess();
      var userId = await signInCreator();
      var entityRef = entityAccess.fsEntityRef(projectId);

      // Refused everywhere: no creatorUserId at all, and no access grant.
      await expectPermissionError(() async {
        await firestore.cvSet(entityRef.cv()..name.v = 'test');
      });

      // Refused everywhere: a creatorUserId, but somebody else's.
      await expectPermissionError(() async {
        await firestore.cvSet(
          entityRef.cv()
            ..name.v = 'test'
            ..creatorUserId.v = 'another_user',
        );
      });

      // The standalone move: claim to be the creator. Allowed only where the
      // creator rules are, i.e. never on an api deployment.
      await expectCreatorPermissionError(() async {
        await firestore.cvSet(
          entityRef.cv()
            ..name.v = 'test'
            ..creatorUserId.v = userId,
        );
      });

      if (effectiveCreatorUserIdCreateSupported) {
        var project = await entityRef.get(firestore);
        expect(project.creatorUserId.v, userId);
      } else {
        // Nothing was written, so nothing can be read back either.
        await expectPermissionError(() async {
          await entityRef.get(firestore);
        });
      }

      await auth.signOut();
    });

    test('standaloneCreateEntity', () async {
      // The helper `projectStandaloneAccessTestRunner` builds its projects
      // with: it sets creatorUserId, writes the entity, then grants itself
      // admin access on it. Every one of those steps needs the creator rules.
      var projectId = 'test_festenao_api_creator_standalone';
      var entityAccess = projectAccess();
      var userId = await signInCreator();
      var entity = entityAccess.fsEntityRef(projectId).cv()..name.v = 'test';

      await expectCreatorPermissionError(() async {
        await entityAccess.standaloneCreateEntity(
          entity: entity,
          userId: userId,
          entityId: projectId,
        );
      });

      if (!effectiveCreatorUserIdCreateSupported) {
        // The access document the helper would have granted itself is not
        // there, so the user still has no way into the entity.
        await expectPermissionError(() async {
          await entityAccess.fsEntityRef(projectId).get(firestore);
        });
      }

      await auth.signOut();
    });
  });
}

import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:festenao_common/test/project_api_access_test_runner.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_auth.dart';

/// In memory version of the emulator `project_api_emulator_test`.
///
/// The whole api (entity create/delete/purge through the cloud function) runs
/// for real against the in memory server, but an in memory firestore carries
/// no security rules: everything the runners expect to be refused goes through
/// instead, hence [ProjectApiAccessTestOptions.rulesSupported] being `false`.
Future<void> main() async {
  late FestenaoTestServerContext testContext;

  group('project api access memory', () {
    setUpAll(() async {
      testContext = await initFestenaoTestServerContextAllMemory();
    });
    tearDownAll(() async {
      await testContext.close();
    });
    group('project api access', () {
      appProjectAccessApiTestRunner(
        () async => testContext.clientContext,
        options: const ProjectApiAccessTestOptions(rulesSupported: false),
      );
    });
    group('project creator access', () {
      appProjectCreatorUserIdApiTestRunner(
        () async => testContext.clientContext,
        options: const ProjectApiAccessTestOptions(rulesSupported: false),
      );
    });
    group('project set public', () {
      late FestenaoServerAppTest serverApp;
      late FirebaseAuth auth;
      late FestenaoApiFsEntityClient<FsProject> client;
      late TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> projectDb;

      Future<void> signIn(String email) => auth.signInOrUpWithEmailAndPassword(
        email: email,
        password: 'test1234',
      );

      setUp(() async {
        // Only the memory server is at hand to set the app condition on, and
        // its project access is the one the server writes through (the
        // runners above build theirs from the client app id).
        serverApp = testContext.ffContext.serverApp as FestenaoServerAppTest;
        auth = testContext.clientContext.firebaseAuth!;
        client = testContext.projectApiClient;
        projectDb = serverApp.fsDatabase.projectDb;
        // The runners above leave nobody signed in.
        await signIn('admin@festenao-memory-test.local');
      });

      test('admin can make a project public, a stranger cannot', () async {
        var projectId = (await client.createEntity(entity: FsProject())).id;
        try {
          expect(await projectDb.isEntityPublic(projectId), isFalse);

          // The creator is an admin of the project: it may publish it.
          expect(
            await client.setEntityPublic(entityId: projectId, public: true),
            isTrue,
          );
          expect(await projectDb.isEntityPublic(projectId), isTrue);

          // A stranger, with no access on the project, may not touch the
          // flag.
          await auth.signOut();
          await signIn('stranger@festenao-memory-test.local');
          try {
            await client.setEntityPublic(entityId: projectId, public: false);
            fail('should fail');
          } on ApiException catch (e) {
            expect(e.error?.code.v, 'permission-denied');
          }
          expect(await projectDb.isEntityPublic(projectId), isTrue);

          // The admin can take it back.
          await auth.signOut();
          await signIn('admin@festenao-memory-test.local');
          expect(
            await client.setEntityPublic(entityId: projectId, public: false),
            isFalse,
          );
          expect(await projectDb.isEntityPublic(projectId), isFalse);
        } finally {
          await client.deleteEntity(entityId: projectId);
          await client.purgeEntity(entityId: projectId);
        }
      });

      test('the app condition refuses even an admin', () async {
        var projectId = (await client.createEntity(entity: FsProject())).id;
        try {
          serverApp.projectSetPublicCheck =
              ({required userId, required entityId}) async => false;
          try {
            await client.setEntityPublic(entityId: projectId, public: true);
            fail('should fail');
          } on ApiException catch (e) {
            expect(e.error?.code.v, 'permission-denied');
          }
          expect(await projectDb.isEntityPublic(projectId), isFalse);

          // Without the condition, being an admin is enough.
          serverApp.projectSetPublicCheck = null;
          expect(
            await client.setEntityPublic(entityId: projectId, public: true),
            isTrue,
          );
          expect(await projectDb.isEntityPublic(projectId), isTrue);
        } finally {
          serverApp.projectSetPublicCheck = null;
          await client.deleteEntity(entityId: projectId);
          await client.purgeEntity(entityId: projectId);
        }
      });
    });
  });
}

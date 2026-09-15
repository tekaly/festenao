import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/test/entity_set_public_api_test_runner.dart';
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
      setUpAll(() {
        // Only the memory server is at hand to set the app condition on, and
        // its project access is the one the server writes through (the
        // runners above build theirs from the client app id).
        serverApp = testContext.ffContext.serverApp as FestenaoServerAppTest;
        auth = testContext.clientContext.firebaseAuth!;
        client = testContext.projectApiClient;
      });

      Future<String> signIn(String email) async {
        await auth.signOut();
        return (await auth.signInOrUpWithEmailAndPassword(
          email: email,
          password: 'test1234',
        )).user.uid;
      }

      EntitySetPublicApiTestContext<FsProject> buildContext({
        required bool privilegeRequired,
        Future<void> Function(String userId, {required bool granted})?
        setPublishPrivilege,
      }) => EntitySetPublicApiTestContext<FsProject>(
        client: client,
        signInAdmin: () => signIn('admin@festenao-memory-test.local'),
        signInStranger: () => signIn('stranger@festenao-memory-test.local'),
        createEntity: () async =>
            (await client.createEntity(entity: FsProject())).id,
        purgeEntity: (entityId) async {
          await client.deleteEntity(entityId: entityId);
          await client.purgeEntity(entityId: entityId);
        },
        privilegeRequired: privilegeRequired,
        setPublishPrivilege: setPublishPrivilege,
      );

      group('admin only', () {
        setUp(() => serverApp.projectSetPublicCheck = null);
        entitySetPublicApiTestRunner<FsProject>(
          () async => buildContext(privilegeRequired: false),
        );
      });

      group('with the app condition', () {
        var grantedUsers = <String>{};
        setUp(() {
          grantedUsers.clear();
          serverApp.projectSetPublicCheck =
              ({required userId, required entityId}) async =>
                  grantedUsers.contains(userId);
        });
        tearDownAll(() => serverApp.projectSetPublicCheck = null);
        entitySetPublicApiTestRunner<FsProject>(
          () async => buildContext(
            privilegeRequired: true,
            setPublishPrivilege: (userId, {required granted}) async {
              if (granted) {
                grantedUsers.add(userId);
              } else {
                grantedUsers.remove(userId);
              }
            },
          ),
        );
      });
    });
  });
}

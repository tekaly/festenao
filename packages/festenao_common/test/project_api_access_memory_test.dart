import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:festenao_common/test/project_api_access_test_runner.dart';
import 'package:test/test.dart';

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
  });
}

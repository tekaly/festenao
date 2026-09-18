import 'package:festenao_common/festenao_quizz.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:festenao_common/test/quizz_server_test_runner.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// The quizz api against the in memory server (`FestenaoServerAppTest` has
/// the quizz handler).
Future<void> main() async {
  late FestenaoTestServerContext testContext;
  setUpAll(() async {
    testContext = await initFestenaoTestServerContextAllMemory();
  });
  tearDownAll(() async {
    await testContext.close();
  });
  testQuizzServerGroup(() async {
    var serverApp = testContext.ffContext.serverApp as TkAppCmsServerAppBase;
    var projectId = 'quizz_test';
    return QuizzTestContext(
      apiService: testContext.apiService,
      projectId: projectId,
      database: QuizzFirestoreDatabase(
        firestore: testContext.ffContext.firestore,
        rootDocument: festenaoProjectQuizzRootDocument(
          app: serverApp.app,
          projectId: projectId,
        ),
      ),
    );
  });
}

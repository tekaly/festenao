import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/test/festenao_email_invite_test_runner.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

const _commandPing = 'test_module/ping';
const _commandProject = 'test_module/project';

/// A module of the test: answers its ping, and its project command to the
/// writers of the project only (`entityId` of the echo data).
class _TestModuleHandler implements FestenaoApiHandler {
  final FestenaoProjectsServerApp app;

  _TestModuleHandler(this.app);

  @override
  Future<ApiResult?> onCommandOrNull(ApiRequest apiRequest) async {
    switch (apiRequest.command.v) {
      case _commandPing:
        return ApiEmpty();
      case _commandProject:
        var query = apiRequest.query<ApiEchoQuery>();
        await app.projectHandler.requireUserAccess(
          entityId: query.data.v!['entityId'] as String,
          userId: apiRequest.userId.v!,
          write: true,
        );
        return ApiEmpty();
    }
    return null;
  }
}

/// The handlers a module registers on the projects server app, and the
/// project access check they use.
void main() {
  late FestenaoTestServerContext context;
  late FestenaoServerAppTest serverApp;

  setUpAll(() async {
    context = await initFestenaoTestServerContextAllMemory();
    serverApp = context.ffContext.serverApp as FestenaoServerAppTest;
    serverApp.moduleApiHandlers.add(_TestModuleHandler(serverApp));
  });
  tearDownAll(() async {
    await context.close();
  });

  Future<void> projectCommand(String entityId) =>
      context.apiService.getApiResult<ApiEmpty>(
        ApiRequest(command: _commandProject)
          ..setQuery(ApiEchoQuery()..data.v = {'entityId': entityId}),
      );

  test('a module command is served', () async {
    await context.apiService.getApiResult<ApiEmpty>(
      ApiRequest(command: _commandPing),
    );
  });

  test('requireUserAccess', () async {
    var auth = context.clientContext.firebaseAuth!;
    var entityId = (await context.projectApiClient.createEntity(
      entity: FsProject()..name.v = 'Module test',
    )).id;
    // The creator is its admin.
    await projectCommand(entityId);

    var readerId = await festenaoLocalAuthSignInVerified(
      context,
      'reader@test.local',
    );
    var projectDb = context.fsDatabase.projectDb;
    await projectDb
        .fsEntityUserAccessRef(entityId, readerId)
        .set(context.fsDatabase.firestore, TkCmsFsUserAccess()..read.v = true);
    try {
      await projectCommand(entityId);
      fail('should fail');
    } on ApiException catch (e) {
      expect(e.error?.code.v, HttpsErrorCode.permissionDenied);
    }
    await serverApp.projectHandler.requireUserAccess(
      entityId: entityId,
      userId: readerId,
    );

    await projectDb
        .fsEntityUserAccessRef(entityId, readerId)
        .set(context.fsDatabase.firestore, TkCmsFsUserAccess()..write.v = true);
    await projectCommand(entityId);
    try {
      await serverApp.projectHandler.requireUserAccess(
        entityId: entityId,
        userId: readerId,
        admin: true,
      );
      fail('should fail');
    } on ApiException catch (e) {
      expect(e.error?.code.v, HttpsErrorCode.permissionDenied);
    }

    await festenaoLocalAuthSignInVerified(context, 'stranger@test.local');
    try {
      await projectCommand(entityId);
      fail('should fail');
    } on ApiException catch (e) {
      expect(e.error?.code.v, HttpsErrorCode.permissionDenied);
    }
    await auth.signOut();
  });
}

import 'package:festenao_common/api/gdrive_api_service.dart';
import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_common/server/festeano_server_object_storage_handler.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_server.dart';

void main() {
  late FestenaoObjectStorageHandler handler;
  setUpAll(() async {
    initGdriveApiBuilders();
    var fs = newFileSystemMemory();
    await fs.directory('/storage/folder').create(recursive: true);
    await fs.file('/storage/folder/a.txt').writeAsString('a');
    handler = FestenaoObjectStorageHandler(
      options: FestenaoObjectStorageHandlerOptions(
        objectStorage: ObjectStorageFs(fileSystem: fs, rootPath: '/storage'),
        readOnly: true,
        authenticatedCommands: const {GdriveApiService.listCommand},
      ),
    );
  });

  Matcher throwsApiCode(String code) =>
      throwsA(isA<ApiException>().having((e) => e.error?.code.v, 'code', code));

  test('authenticated commands need a user', () async {
    var request = (GdriveApiListQuery()..path.v = 'folder').request(
      GdriveApiService.listCommand,
    );
    await expectLater(
      handler.onCommandOrNull(request),
      throwsApiCode(HttpsErrorCode.unauthenticated),
    );
    request.userId.v = 'user1';
    var result = await handler.onCommandOrNull(request) as GdriveApiListResult;
    expect(result.items.v!.map((item) => item.name.v), ['a.txt']);
  });

  test('reads stay open, writes are refused', () async {
    var getItem = (GdriveApiGetItemQuery()..path.v = 'folder/a.txt').request(
      GdriveApiService.getItemCommand,
    );
    expect(await handler.onCommandOrNull(getItem), isNotNull);
    var delete = (GdriveApiDeleteQuery()..path.v = 'folder/a.txt').request(
      GdriveApiService.deleteCommand,
    )..userId.v = 'user1';
    await expectLater(
      handler.onCommandOrNull(delete),
      throwsApiCode(HttpsErrorCode.permissionDenied),
    );
  });

  test('other commands are not handled', () async {
    expect(await handler.onCommandOrNull(ApiRequest(command: 'other')), isNull);
  });
}

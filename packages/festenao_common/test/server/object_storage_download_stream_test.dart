import 'dart:convert';

import 'package:festenao_common/api/gdrive_api_service.dart';
import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_common/server/festeano_server_object_storage_handler.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_server.dart';

void main() {
  late ObjectStorageFs storage;
  late FestenaoObjectStorageDownloadStream stream;
  final commandUri = Uri.parse('https://example.com/commanddartv2dev');

  setUpAll(() async {
    initGdriveApiBuilders();
    var fs = newFileSystemMemory();
    await fs.directory('/storage/folder').create(recursive: true);
    await fs.file('/storage/folder/a.mid').writeAsString('0123456789');
    storage = ObjectStorageFs(fileSystem: fs, rootPath: '/storage');
    stream = FestenaoObjectStorageDownloadStream(
      objectStorage: storage,
      commandUri: () => commandUri,
    );
  });

  Future<String> bodyText(DownloadStreamResponse response) async =>
      utf8.decode([await for (var chunk in response.body!) ...chunk]);

  group('DownloadToken', () {
    test('round trip with its key only', () {
      var key = randomDownloadTokenKey();
      var token = DownloadToken(path: 'folder/a.mid');
      var decoded = DownloadToken.tryDecode(token.encode(key), key)!;
      expect(decoded.path, 'folder/a.mid');
      expect(decoded.isExpired, isFalse);
      expect(
        DownloadToken.tryDecode(token.encode(key), randomDownloadTokenKey()),
        isNull,
      );
      expect(DownloadToken.tryDecode('garbage', key), isNull);
      expect(DownloadToken.tryDecode(null, key), isNull);
    });

    test('a key from a secret is stable and of the right length', () {
      var key = downloadTokenKeyFromSecret('secret');
      expect(key, downloadTokenKeyFromSecret('secret'));
      expect(key.length, downloadTokenKeyLength);
    });
  });

  group('stream', () {
    test('the url is the stream endpoint below the command function', () {
      var url = stream.downloadUrl('folder/a.mid');
      expect(url.path, '/commanddartv2dev/gdrive/stream');
      expect(url.queryParameters[downloadStreamTokenParam], isNotEmpty);
      expect(stream.isDownloadStreamUri(url), isTrue);
      expect(stream.isDownloadStreamUri(Uri.parse('/gdrive/stream')), isTrue);
      expect(stream.isDownloadStreamUri(commandUri), isFalse);
    });

    test('other urls are not handled', () async {
      expect(
        await stream.onDownloadStreamOrNull(method: 'POST', uri: commandUri),
        isNull,
      );
    });

    test('the whole file, then a range', () async {
      var url = stream.downloadUrl('folder/a.mid');
      var whole = (await stream.onDownloadStreamOrNull(
        method: 'GET',
        uri: url,
      ))!;
      expect(whole.statusCode, 200);
      expect(whole.headers['content-length'], '10');
      expect(await bodyText(whole), '0123456789');

      var part = (await stream.onDownloadStreamOrNull(
        method: 'GET',
        uri: url,
        range: 'bytes=2-4',
      ))!;
      expect(part.statusCode, 206);
      expect(part.headers['content-range'], 'bytes 2-4/10');
      expect(part.headers['content-length'], '3');
      expect(await bodyText(part), '234');
    });

    test('errors', () async {
      var url = stream.downloadUrl('folder/a.mid');
      Future<int> status(
        Uri uri, {
        String method = 'GET',
        String? range,
      }) async => (await stream.onDownloadStreamOrNull(
        method: method,
        uri: uri,
        range: range,
      ))!.statusCode;

      expect(await status(url, method: 'POST'), 405);
      expect(await status(url, range: 'bytes=10-'), 416);
      expect(
        await status(
          url.replace(queryParameters: {downloadStreamTokenParam: 'forged'}),
        ),
        403,
      );
      var expired = DownloadToken(
        path: 'folder/a.mid',
        expires: DateTime.timestamp().subtract(const Duration(seconds: 1)),
      ).encode(stream.key);
      expect(
        await status(
          url.replace(queryParameters: {downloadStreamTokenParam: expired}),
        ),
        403,
      );
      expect(await status(stream.downloadUrl('folder/missing.mid')), 404);
    });
  });

  test('the handler answers the stream url when given one', () async {
    var request = (GdriveApiGetDownloadUrlQuery()..path.v = 'folder/a.mid')
        .request(GdriveApiService.getDownloadUrlCommand);
    var withStream = FestenaoObjectStorageHandler(
      options: FestenaoObjectStorageHandlerOptions(
        objectStorage: storage,
        readOnly: true,
        downloadStream: stream,
      ),
    );
    var result =
        await withStream.onCommandOrNull(request)
            as GdriveApiGetDownloadUrlResult;
    var url = Uri.parse(result.url.v!);
    expect(stream.isDownloadStreamUri(url), isTrue);
    var response = (await stream.onDownloadStreamOrNull(
      method: 'GET',
      uri: url,
    ))!;
    expect(await bodyText(response), '0123456789');

    var withoutStream = FestenaoObjectStorageHandler(
      options: FestenaoObjectStorageHandlerOptions(objectStorage: storage),
    );
    var storageResult =
        await withoutStream.onCommandOrNull(request)
            as GdriveApiGetDownloadUrlResult;
    // The storage's own url (none for a file system).
    expect(storageResult.url.v, isNull);
  });
}

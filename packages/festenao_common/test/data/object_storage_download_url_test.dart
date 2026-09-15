import 'dart:typed_data';

import 'package:festenao_common/festenao_http.dart';
import 'package:festenao_common/src/data/storage/object_storage.dart';
import 'package:festenao_common/src/data/storage/object_storage_api.dart';
import 'package:tekartik_app_media/mime_type.dart';
import 'package:test/test.dart';

import 'object_storage_test.dart';

/// An in-memory storage whose files are also served over the in-memory http
/// server, so a download url can be exercised without any network.
///
/// [supportDownloadUrl] is what is tested: with it the download stream goes
/// through the url, without it through [downloadPart]. Both are counted.
class MockObjectStorage extends ObjectStorage {
  @override
  final bool supportDownloadUrl;

  /// Serves the whole content (200) whatever the range asked, to test the
  /// client side handling of a server ignoring ranges.
  bool ignoreRange = false;

  /// [getDownloadUrl] returns null even when [supportDownloadUrl].
  bool noUrl = false;

  final _files = <String, Uint8List>{};
  final _meta = <String, _MockMeta>{};
  var _nextId = 0;

  /// How many times each entry point was called.
  var downloadPartCount = 0;
  var getDownloadUrlCount = 0;

  /// The `Range` headers received by the server, in order (null when none).
  final rangesReceived = <String?>[];

  HttpServer? _server;
  late final Uri _serverUri;

  MockObjectStorage({required this.supportDownloadUrl});

  /// Start the http server serving the files.
  Future<void> start() async {
    var server = _server = await httpServerFactoryMemory.bind(
      InternetAddress.anyIPv4,
      0,
    );
    _serverUri = httpServerGetUri(server);
    server.listen(_onRequest);
  }

  Future<void> _onRequest(HttpRequest request) async {
    var response = request.response;
    var path = request.uri.pathSegments.last;
    var data = _files[path];
    if (data == null) {
      response.statusCode = 404;
      await response.close();
      return;
    }
    var range = request.headers.value('range');
    rangesReceived.add(range);
    var bytes = data;
    if (range != null && !ignoreRange) {
      // bytes=<start>-<end?>
      var parts = range.substring('bytes='.length).split('-');
      var start = int.parse(parts[0]);
      var end = parts[1].isEmpty ? data.length - 1 : int.parse(parts[1]);
      if (end >= data.length) {
        end = data.length - 1;
      }
      bytes = Uint8List.sublistView(data, start, end + 1);
      response.statusCode = 206;
      response.headers.set('content-range', 'bytes $start-$end/${data.length}');
    } else {
      response.statusCode = 200;
    }
    response.headers.set('content-length', bytes.length);
    // Two writes, so the client sees more than one chunk.
    var half = bytes.length ~/ 2;
    response.add(Uint8List.sublistView(bytes, 0, half));
    response.add(Uint8List.sublistView(bytes, half));
    await response.close();
  }

  /// Stop the server.
  Future<void> close() async {
    await _server?.close();
    _server = null;
  }

  @override
  HttpClientFactory get downloadHttpClientFactory => httpClientFactoryMemory;

  @override
  Future<String?> getDownloadUrl(String path) async {
    getDownloadUrlCount++;
    if (noUrl) {
      return null;
    }
    return _serverUri.resolve('file/$path').toString();
  }

  @override
  Future<Uint8List> download(String path) async {
    var data = _files[path];
    if (data == null) {
      throw StateError('not found: $path');
    }
    return data;
  }

  @override
  Future<Uint8List> downloadPart(String path, int start, int size) async {
    downloadPartCount++;
    var data = await download(path);
    var end = start + size;
    if (end > data.length) {
      end = data.length;
    }
    if (start >= end) {
      return Uint8List(0);
    }
    return Uint8List.sublistView(data, start, end);
  }

  @override
  Future<void> delete(String path) async {
    _files.remove(path);
    _meta.remove(path);
  }

  @override
  Future<ObjectStorageMeta> getItem(String path) async {
    var meta = _meta[path];
    if (meta == null) {
      throw StateError('not found: $path');
    }
    return meta;
  }

  @override
  Future<ObjectStorageListResponse> list(
    String path, {
    String? pageToken,
    int? maxResults,
  }) async {
    return _MockListResponse(
      _meta.values.where((meta) => meta.location == path).toList(),
    );
  }

  @override
  Future<ObjectStorageMeta> upload(
    String path, {
    required String name,
    required Uint8List data,
    required String mimeType,
  }) async {
    var id = 'f${++_nextId}';
    _files[id] = data;
    return _meta[id] = _MockMeta(
      name: name,
      path: id,
      location: path,
      size: data.length,
      mimeType: mimeType,
    );
  }
}

class _MockMeta implements ObjectStorageMeta {
  @override
  final String name;
  @override
  final String path;
  final String location;
  @override
  final int? size;
  @override
  final String? mimeType;

  _MockMeta({
    required this.name,
    required this.path,
    required this.location,
    this.size,
    this.mimeType,
  });

  @override
  bool get isLocation => false;
}

class _MockListResponse implements ObjectStorageListResponse {
  @override
  final List<ObjectStorageMeta> items;

  _MockListResponse(this.items);

  @override
  String? get nextPageToken => null;
}

class _MockContext implements ObjectStorageTestContext {
  @override
  final MockObjectStorage storage;

  _MockContext(this.storage);

  @override
  Future<void> dispose() => storage.close();
}

Uint8List _concat(List<Uint8List> chunks) =>
    Uint8List.fromList(chunks.expand((c) => c).toList());

void main() {
  for (var supportDownloadUrl in [false, true]) {
    group('mock (supportDownloadUrl: $supportDownloadUrl)', () {
      late MockObjectStorage storage;
      final data = Uint8List.fromList(List.generate(10, (i) => i + 1));

      Future<String> uploadData() async => (await storage.upload(
        'test',
        name: 'file.bin',
        data: data,
        mimeType: mimeTypeOctetStream,
      )).path;

      setUp(() async {
        storage = MockObjectStorage(supportDownloadUrl: supportDownloadUrl);
        await storage.start();
      });
      tearDown(() => storage.close());

      // The shared contract holds either way.
      objectStorageTest(() => _MockContext(storage));

      test('downloadStream goes through the url or the parts', () async {
        var path = await uploadData();
        var chunks = await storage.downloadStream(path, chunkSize: 3).toList();
        expect(_concat(chunks), data);
        for (var chunk in chunks) {
          expect(chunk.length, lessThanOrEqualTo(3));
        }
        if (supportDownloadUrl) {
          expect(storage.getDownloadUrlCount, 1);
          expect(storage.downloadPartCount, 0);
          // The whole file: no range asked.
          expect(storage.rangesReceived, [null]);
        } else {
          expect(storage.getDownloadUrlCount, 0);
          // 10 bytes, 3 at a time: 3, 3, 3, 1.
          expect(storage.downloadPartCount, 4);
          expect(storage.rangesReceived, isEmpty);
        }
      });

      test('downloadStream of a part', () async {
        var path = await uploadData();
        var chunks = await storage
            .downloadStream(path, start: 2, size: 5, chunkSize: 2)
            .toList();
        expect(_concat(chunks), Uint8List.fromList([3, 4, 5, 6, 7]));
        if (supportDownloadUrl) {
          expect(storage.getDownloadUrlCount, 1);
          expect(storage.downloadPartCount, 0);
          expect(storage.rangesReceived, ['bytes=2-6']);
        } else {
          expect(storage.getDownloadUrlCount, 0);
          expect(storage.downloadPartCount, 3);
        }
      });

      test('downloadStream from a start, to the end', () async {
        var path = await uploadData();
        var chunks = await storage
            .downloadStream(path, start: 7, chunkSize: 2)
            .toList();
        expect(_concat(chunks), Uint8List.fromList([8, 9, 10]));
        if (supportDownloadUrl) {
          expect(storage.rangesReceived, ['bytes=7-']);
        }
      });

      test('downloadStream of a part, server ignoring the range', () async {
        storage.ignoreRange = true;
        var path = await uploadData();
        var chunks = await storage
            .downloadStream(path, start: 2, size: 5, chunkSize: 2)
            .toList();
        expect(_concat(chunks), Uint8List.fromList([3, 4, 5, 6, 7]));
      });

      test('downloadStream without a url falls back to the parts', () async {
        storage.noUrl = true;
        var path = await uploadData();
        var chunks = await storage.downloadStream(path, chunkSize: 4).toList();
        expect(_concat(chunks), data);
        expect(storage.getDownloadUrlCount, supportDownloadUrl ? 1 : 0);
        expect(storage.downloadPartCount, 3);
      });

      test('downloadStream of a missing file fails', () async {
        expect(
          () => storage.downloadStream('missing', chunkSize: 4).toList(),
          throwsA(anything),
        );
      });
    });
  }

  test('the api client goes through the parts', () {
    // The api client is not the storage itself: the url it hands out is the
    // server's business.
    var client = ObjectStorageApiClient(httpsUri: Uri.parse('http://_/api'));
    expect(client.supportDownloadUrl, isFalse);
  });
}

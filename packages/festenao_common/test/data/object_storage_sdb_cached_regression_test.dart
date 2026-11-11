import 'package:festenao_common/data/object_storage.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import 'package:test/test.dart';

final _data = Uint8List.fromList([1, 2, 3]);
const _mimeType = 'application/octet-stream';

class _ListResponse implements ObjectStorageListResponse {
  @override
  final List<ObjectStorageMeta> items;
  @override
  final String? nextPageToken;
  _ListResponse(this.items, this.nextPageToken);
}

/// A store in front of [inner] paging its listings one item at a time (as
/// google drive or firebase storage page theirs), and going [offline] on
/// demand: every call then throws a network like error.
class _TestDelegate extends ObjectStorage {
  final ObjectStorage inner;
  var offline = false;

  _TestDelegate(this.inner);

  void _check() {
    if (offline) {
      throw Exception('offline');
    }
  }

  @override
  Future<ObjectStorageListResponse> list(
    String path, {
    String? pageToken,
    int? maxResults,
  }) async {
    _check();
    var all = (await inner.list(path)).items;
    var index = int.parse(pageToken ?? '0');
    var size = maxResults ?? 1;
    var next = index + size < all.length ? '${index + size}' : null;
    return _ListResponse(all.skip(index).take(size).toList(), next);
  }

  @override
  Future<ObjectStorageMeta> getItem(String path) async {
    _check();
    return inner.getItem(path);
  }

  @override
  Future<ObjectStorageMeta> upload(
    String path, {
    required String name,
    required Uint8List data,
    required String mimeType,
  }) async {
    _check();
    return inner.upload(path, name: name, data: data, mimeType: mimeType);
  }

  @override
  Future<Uint8List> download(String path) async {
    _check();
    return inner.download(path);
  }

  @override
  Future<Uint8List> downloadPart(String path, int start, int size) async {
    _check();
    return inner.downloadPart(path, start, size);
  }

  @override
  Future<void> delete(String path) async {
    _check();
    return inner.delete(path);
  }
}

Future<List<String>> _listAllNames(ObjectStorage storage, String path) async {
  var names = <String>[];
  String? pageToken;
  var pages = 0;
  do {
    var response = await storage.list(path, pageToken: pageToken);
    names.addAll(response.items.map((item) => item.name));
    pageToken = response.nextPageToken;
  } while (pageToken != null && ++pages < 10);
  return names;
}

void main() {
  late ObjectStorageFs source;
  late _TestDelegate delegate;
  late ObjectStorageSdb cache;
  late ObjectStorageSdbCached cached;

  setUp(() {
    source = ObjectStorageFs(fileSystem: newFileSystemMemory(), rootPath: '/r');
    delegate = _TestDelegate(source);
    cache = ObjectStorageSdb(
      factory: newSdbFactoryMemory(),
      fileSystem: newFileSystemMemory(),
      rootPath: '/c',
    );
    cached = ObjectStorageSdbCached(delegate: delegate, cache: cache);
  });

  tearDown(() async {
    // Let the background refreshes end before closing.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await cache.close();
  });

  test('paged listing through the cache', () async {
    for (var name in ['a.bin', 'b.bin', 'c.bin']) {
      await source.upload('dir', name: name, data: _data, mimeType: _mimeType);
    }
    expect(await _listAllNames(cached, 'dir'), ['a.bin', 'b.bin', 'c.bin']);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await _listAllNames(cached, 'dir'), ['a.bin', 'b.bin', 'c.bin']);
    // A complete listing is served from the cache.
    var all = await cached.list('dir', maxResults: 10);
    expect(all.items.map((item) => item.name), ['a.bin', 'b.bin', 'c.bin']);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    delegate.offline = true;
    var offline = await cached.list('dir');
    expect(offline.items.map((item) => item.name), ['a.bin', 'b.bin', 'c.bin']);
    expect(offline.nextPageToken, isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('cached content survives the delegate going offline', () async {
    await source.upload(
      'songs',
      name: 'a.bin',
      data: _data,
      mimeType: _mimeType,
    );
    expect(await cached.download('songs/a.bin'), _data);
    delegate.offline = true;
    expect(await cached.download('songs/a.bin'), _data);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await cached.download('songs/a.bin'), _data);
    expect(await cached.downloadPart('songs/a.bin', 1, 2), [2, 3]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // A folder refreshed while offline keeps its files.
    expect((await cached.getItem('songs')).isLocation, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await cache.hasLocalContent('songs/a.bin'), isTrue);
    expect((await cached.getItem('songs/a.bin')).size, 3);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await cache.hasLocalContent('songs/a.bin'), isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('an object deleted from the delegate leaves the cache', () async {
    await source.upload(
      'songs',
      name: 'a.bin',
      data: _data,
      mimeType: _mimeType,
    );
    expect(await cached.download('songs/a.bin'), _data);
    await source.delete('songs/a.bin');
    // Served from the cache, the refresh finds it gone.
    expect(await cached.download('songs/a.bin'), _data);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await cache.hasLocalContent('songs/a.bin'), isFalse);
    await expectLater(cached.download('songs/a.bin'), throwsA(anything));
  }, timeout: const Timeout(Duration(seconds: 30)));
}

import 'package:festenao_common/data/object_storage.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import 'package:test/test.dart';

import 'object_storage_test.dart';

class ObjectStorageSdbCachedTestContext implements ObjectStorageTestContext {
  @override
  final ObjectStorageSdbCached storage;
  final ObjectStorageSdb cache;
  final ObjectStorageSdb delegate;

  ObjectStorageSdbCachedTestContext({
    required this.storage,
    required this.cache,
    required this.delegate,
  });

  @override
  Future<void> dispose() async {
    await cache.close();
    await delegate.close();
  }

  static ObjectStorageSdbCachedTestContext memory() {
    var delegate = ObjectStorageSdb.inMemory();
    var cacheFs = newFileSystemMemory();
    var cache = ObjectStorageSdb(
      factory: sdbFactoryMemory,
      fileSystem: cacheFs,
      name: 'cache_memory',
      rootPath: '/cache_root',
    );
    var storage = ObjectStorageSdbCached(delegate: delegate, cache: cache);
    return ObjectStorageSdbCachedTestContext(
      storage: storage,
      cache: cache,
      delegate: delegate,
    );
  }
}

void main() {
  group('object_storage_sdb_cached_memory', () {
    objectStorageTest(ObjectStorageSdbCachedTestContext.memory);

    test('write and read simple text file', () async {
      var ctx = ObjectStorageSdbCachedTestContext.memory();
      var text = 'Hello SDB Cached Storage!';
      var data = Uint8List.fromList(text.codeUnits);

      var meta = await ctx.storage.upload(
        'text_test',
        name: 'hello.txt',
        data: data,
        mimeType: 'text/plain',
      );

      expect(meta.name, 'hello.txt');
      expect(meta.mimeType, 'text/plain');

      var downloaded = await ctx.storage.download(meta.path);
      var downloadedText = String.fromCharCodes(downloaded);
      expect(downloadedText, text);

      await ctx.dispose();
    });

    test('cache usage and async refresh', () async {
      var ctx = ObjectStorageSdbCachedTestContext.memory();

      // 1. Upload directly to the delegate to bypass cached writer (simulating another client uploading)
      var text1 = 'Content 1';
      var data1 = Uint8List.fromList(text1.codeUnits);
      await ctx.delegate.upload('my_test', name: 'cached.txt', data: data1, mimeType: 'text/plain');

      // 2. Fetch via cached storage. First fetch must go to the delegate (cache miss)
      var meta = await ctx.storage.getItem('my_test/cached.txt');
      expect(meta.name, 'cached.txt');

      var dataDownloaded = await ctx.storage.download('my_test/cached.txt');
      expect(String.fromCharCodes(dataDownloaded), text1);

      // 3. Now modify the delegate content directly (simulating another client updating)
      var text2 = 'Content 2';
      var data2 = Uint8List.fromList(text2.codeUnits);
      await ctx.delegate.upload('my_test', name: 'cached.txt', data: data2, mimeType: 'text/plain');

      // 4. Download from cached storage. It should hit the cache and return the OLD content first
      var cachedDownloaded = await ctx.storage.download('my_test/cached.txt');
      expect(String.fromCharCodes(cachedDownloaded), text1);

      // Wait a bit to let the async refresh complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 5. Subsequent download should now return the updated content (cache hit updated)
      var updatedDownloaded = await ctx.storage.download('my_test/cached.txt');
      expect(String.fromCharCodes(updatedDownloaded), text2);

      await ctx.dispose();
    });
  });
}

import 'package:festenao_common/data/object_storage.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import 'package:test/test.dart';

void main() {
  var data = Uint8List.fromList([1, 2, 3]);
  var mimeType = 'application/octet-stream';

  test('fs and sdb paths stay below the root', () async {
    for (var kind in ['fs', 'sdb']) {
      var fileSystem = newFileSystemMemory();
      var storage = kind == 'fs'
          ? ObjectStorageFs(fileSystem: fileSystem, rootPath: '/root')
          : ObjectStorageSdb(
              factory: newSdbFactoryMemory(),
              fileSystem: fileSystem,
              rootPath: '/root',
            );
      await storage.upload(
        '/etc',
        name: 'passwd',
        data: data,
        mimeType: mimeType,
      );
      expect(
        await fileSystem.file('/etc/passwd').exists(),
        isFalse,
        reason: kind,
      );
      expect(
        await fileSystem.file('/root/etc/passwd').exists(),
        isTrue,
        reason: kind,
      );
      await expectLater(
        storage.upload('../out', name: 'x.bin', data: data, mimeType: mimeType),
        throwsArgumentError,
        reason: kind,
      );
      expect(
        await fileSystem.file('/out/x.bin').exists(),
        isFalse,
        reason: kind,
      );
    }
  });

  test('fs delete a directory on a memory file system', () async {
    var storage = ObjectStorageFs(
      fileSystem: newFileSystemMemory(),
      rootPath: '/root',
    );
    await storage.upload('dir', name: 'x.bin', data: data, mimeType: mimeType);
    await storage.delete('dir');
    expect((await storage.list('dir')).items, isEmpty);
    expect((await storage.list('')).items, isEmpty);
  });

  test('inMemory instances are independent', () async {
    var storage1 = ObjectStorageSdb.inMemory();
    await storage1.upload(
      'shared',
      name: 'x.bin',
      data: data,
      mimeType: mimeType,
    );
    var storage2 = ObjectStorageSdb.inMemory();
    expect((await storage2.list('shared')).items, isEmpty);
    await storage1.close();
    await storage2.close();
  });

  test('cached list keeps the sub directories', () async {
    var delegate = ObjectStorageFs(
      fileSystem: newFileSystemMemory(),
      rootPath: '/r',
    );
    await delegate.upload('a', name: 'x.bin', data: data, mimeType: mimeType);
    await delegate.upload(
      'a/sub',
      name: 'y.bin',
      data: data,
      mimeType: mimeType,
    );
    var cache = ObjectStorageSdb(
      factory: newSdbFactoryMemory(),
      fileSystem: newFileSystemMemory(),
      rootPath: '/c',
    );
    var cached = ObjectStorageSdbCached(delegate: delegate, cache: cache);
    String describe(ObjectStorageListResponse response) => response.items
        .map((item) => '${item.name}${item.isLocation ? '/' : ''}')
        .join(',');
    expect(describe(await cached.list('a')), 'sub/,x.bin');
    // From the cache now.
    expect(describe(await cached.list('a')), 'sub/,x.bin');
    await cache.close();
  });
}

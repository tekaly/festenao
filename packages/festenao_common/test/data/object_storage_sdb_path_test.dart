import 'package:festenao_common/data/object_storage.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import 'package:test/test.dart';

void main() {
  var data = Uint8List.fromList([1, 2, 3]);
  var mimeType = 'application/octet-stream';

  test('sdb paths are normalized, as fs ones', () async {
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
        '/songs',
        name: 'a.bin',
        data: data,
        mimeType: mimeType,
      );
      for (var path in ['songs', '/songs', 'songs/', './songs']) {
        expect((await storage.list(path)).items.map((item) => item.name), [
          'a.bin',
        ], reason: '$kind list($path)');
      }
      expect((await storage.list('songs')).items.map((item) => item.path), [
        'songs/a.bin',
      ], reason: kind);
      expect((await storage.list('')).items.map((item) => item.path), [
        'songs',
      ], reason: kind);
      // The same object, whatever the spelling.
      await storage.upload(
        'songs/',
        name: 'a.bin',
        data: data,
        mimeType: mimeType,
      );
      expect((await storage.list('songs')).items, hasLength(1), reason: kind);
      expect(await storage.download('/songs/a.bin'), data, reason: kind);
      expect((await storage.getItem('songs//a.bin')).size, 3, reason: kind);
      expect(
        (await storage.getItem('/songs')).isLocation,
        isTrue,
        reason: kind,
      );
      await storage.delete('/songs/a.bin');
      expect((await storage.list('songs')).items, isEmpty, reason: kind);
      await expectLater(
        storage.list('../out'),
        throwsArgumentError,
        reason: kind,
      );
      if (storage is ObjectStorageSdb) {
        await storage.close();
      }
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}

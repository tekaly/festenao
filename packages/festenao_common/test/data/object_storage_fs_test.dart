import 'package:festenao_common/data/object_storage.dart';
import 'package:fs_shim/fs_io.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tekartik_common_utils/env_utils.dart';
import 'package:test/test.dart';

import 'object_storage_test.dart';

class ObjectStorageFsTestContext implements ObjectStorageTestContext {
  @override
  final ObjectStorageFs storage;
  final FileSystem fileSystem;
  final String rootPath;
  final Future<void> Function()? onDispose;

  ObjectStorageFsTestContext({
    required this.storage,
    required this.fileSystem,
    required this.rootPath,
    this.onDispose,
  });

  @override
  Future<void> dispose() async {
    if (onDispose != null) {
      await onDispose!();
    }
  }

  static ObjectStorageFsTestContext memory() {
    var fs = newFileSystemMemory();
    var rootPath = '/root';
    return ObjectStorageFsTestContext(
      storage: ObjectStorageFs(fileSystem: fs, rootPath: rootPath),
      fileSystem: fs,
      rootPath: rootPath,
    );
  }

  static ObjectStorageFsTestContext io(String name) {
    var fs = fileSystemIo;
    var rootPath = fs.path.join(
      '.dart_tool',
      'festenao_common',
      'test',
      'object_storage_fs',
      name,
    );

    Future<void> onDispose() async {
      /*var dir = fs.directory(rootPath);

      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }*/
    }

    return ObjectStorageFsTestContext(
      storage: ObjectStorageFs(fileSystem: fs, rootPath: rootPath),
      fileSystem: fs,
      rootPath: rootPath,
      onDispose: onDispose,
    );
  }
}

void main() {
  group('object_storage_fs_memory', () {
    objectStorageTest(ObjectStorageFsTestContext.memory);

    test('write and read simple text file', () async {
      var ctx = ObjectStorageFsTestContext.memory();
      var text = 'Hello File System!';
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
  });

  if (!kDartIsWeb) {
    group('object_storage_fs_io', () {
      objectStorageTest(() => ObjectStorageFsTestContext.io('standard'));

      test('write and read simple text file', () async {
        var ctx = ObjectStorageFsTestContext.io('text_file');
        var text = 'Hello File System IO!';
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
    });
  }
}

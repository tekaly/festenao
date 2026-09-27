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

/// A folder is a location, a file is not, whatever the file system says of
/// `File.exists` on a directory (true on a memory one).
void folderGetItemTest(ObjectStorageFsTestContext Function() create) {
  test('getItem of a folder and of a file', () async {
    var ctx = create();
    var meta = await ctx.storage.upload(
      'folder_test',
      name: 'hello.txt',
      data: Uint8List.fromList('hello'.codeUnits),
      mimeType: 'text/plain',
    );
    var folder = await ctx.storage.getItem('folder_test');
    expect(folder.isLocation, isTrue);
    expect(folder.name, 'folder_test');
    var file = await ctx.storage.getItem(meta.path);
    expect(file.isLocation, isFalse);
    expect(file.size, 5);
    await expectLater(ctx.storage.getItem('no_such_item'), throwsException);
    await ctx.dispose();
  });
}

void main() {
  group('object_storage_fs_memory', () {
    objectStorageTest(ObjectStorageFsTestContext.memory);
    folderGetItemTest(ObjectStorageFsTestContext.memory);

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
      folderGetItemTest(() => ObjectStorageFsTestContext.io('folder'));

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

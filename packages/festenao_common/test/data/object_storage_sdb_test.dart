import 'package:festenao_common/data/object_storage.dart';
import 'package:fs_shim/fs_io.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import 'package:test/test.dart';

import 'object_storage_test.dart';

class ObjectStorageSdbTestContext implements ObjectStorageTestContext {
  @override
  final ObjectStorageSdb storage;
  final String dbName;
  final Future<void> Function()? onDispose;

  ObjectStorageSdbTestContext({
    required this.storage,
    required this.dbName,
    this.onDispose,
  });

  @override
  Future<void> dispose() async {
    await storage.close();
    if (onDispose != null) {
      await onDispose!();
    }
  }

  static ObjectStorageSdbTestContext memory() {
    return ObjectStorageSdbTestContext(
      storage: ObjectStorageSdb.inMemory(),
      dbName: 'in_memory',
    );
  }

  static ObjectStorageSdbTestContext io(String name) {
    var factory = sdbFactoryIo;
    var dbName = '.dart_tool/festenao_common/test/object_storage_sdb/test_$name.db';
    var fs = fileSystemIo;
    var rootPath = fs.path.join('.dart_tool', 'festenao_common', 'test', 'object_storage_sdb', 'fs_$name');

    Future<void> onDispose() async {
      await factory.deleteDatabase(dbName);
      var dir = fs.directory(rootPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }

    return ObjectStorageSdbTestContext(
      storage: ObjectStorageSdb(
        factory: factory,
        fileSystem: fs,
        name: dbName,
        rootPath: rootPath,
      ),
      dbName: dbName,
      onDispose: onDispose,
    );
  }
}

void main() {
  group('object_storage_sdb_memory', () {
    objectStorageTest(ObjectStorageSdbTestContext.memory);

    test('write and read simple text file', () async {
      var ctx = ObjectStorageSdbTestContext.memory();
      var text = 'Hello SDB Storage!';
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

  group('object_storage_sdb_io', () {
    objectStorageTest(() => ObjectStorageSdbTestContext.io('standard'));

    test('write and read simple text file', () async {
      var ctx = ObjectStorageSdbTestContext.io('text_file');
      var text = 'Hello SDB Storage IO!';
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

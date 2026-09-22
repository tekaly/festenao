import 'package:festenao_common/src/fs/sembast_fs_shim.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:idb_shim/sdb.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

void main() {
  group('sembast over fs_shim', () {
    test('writes and reads back a database file', () async {
      var fileSystem = newFileSystemMemory();
      var factory = getDatabaseFactoryFsShim(fileSystem);
      var store = stringMapStoreFactory.store('config');

      var db = await factory.openDatabase('sub/dir/test.db');
      await store.record('main').put(db, {'name': 'test', 'count': 1});
      await db.close();

      // The database really is a file of that file system.
      expect(await fileSystem.file('sub/dir/test.db').exists(), isTrue);
      var content = await fileSystem.file('sub/dir/test.db').readAsString();
      expect(content, contains('"sembast"'));
      expect(content, contains('"name":"test"'));

      // And it reopens.
      var reopened = await factory.openDatabase('sub/dir/test.db');
      expect(await store.record('main').get(reopened), {
        'name': 'test',
        'count': 1,
      });
      await reopened.close();
    });

    test('survives the compaction that rewrites the file', () async {
      var fileSystem = newFileSystemMemory();
      var factory = getDatabaseFactoryFsShim(fileSystem);
      var store = stringMapStoreFactory.store('records');

      var db = await factory.openDatabase('compact.db');
      for (var i = 0; i < 100; i++) {
        await store.record('key_$i').put(db, {'index': i});
      }
      // Rewrites the file through the tmp file and the rename.
      await db.compact();
      expect(await store.count(db), 100);
      await db.close();

      var reopened = await factory.openDatabase('compact.db');
      expect(await store.count(reopened), 100);
      expect(await store.record('key_42').get(reopened), {'index': 42});
      await reopened.close();
    });

    test('deletes a database', () async {
      var fileSystem = newFileSystemMemory();
      var factory = getDatabaseFactoryFsShim(fileSystem);
      var db = await factory.openDatabase('gone.db');
      await db.close();
      expect(await factory.databaseExists('gone.db'), isTrue);
      await factory.deleteDatabase('gone.db');
      expect(await fileSystem.file('gone.db').exists(), isFalse);
    });

    test('writes and reads back an sdb database file', () async {
      var fileSystem = newFileSystemMemory();
      var factory = getSdbFactoryFsShim(fileSystem);
      var store = SdbStoreRef<String, SdbModel>('config');

      var db = await factory.openDatabase(
        'sdb/test.db',
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [store.schema()]),
        ),
      );
      await store.record('main').put(db, {'name': 'sdb'});
      await db.close();

      expect(await fileSystem.file('sdb/test.db').exists(), isTrue);

      var reopened = await factory.openDatabase(
        'sdb/test.db',
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [store.schema()]),
        ),
      );
      expect(await store.record('main').getValue(reopened), {'name': 'sdb'});
      await reopened.close();
    });
  });
}

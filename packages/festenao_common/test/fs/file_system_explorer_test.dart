import 'package:festenao_common/data/object_editor.dart';
import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:idb_shim/sdb.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:test/test.dart';

/// A file system holding a small tree, the explorer being rooted at `root`.
Future<FileSystem> _newFileSystem() async {
  var fileSystem = newFileSystemMemory();
  await fileSystem.file('root/config.json').create(recursive: true);
  await fileSystem.file('root/config.json').writeAsString('{"name":"test"}');
  await fileSystem.file('root/settings.yaml').create(recursive: true);
  await fileSystem.file('root/settings.yaml').writeAsString('''
# kept
count: 1
''');
  await fileSystem.file('root/notes.txt').create(recursive: true);
  await fileSystem.file('root/notes.txt').writeAsString('hello');
  await fileSystem.file('root/sub/nested.json').create(recursive: true);
  await fileSystem.file('root/sub/nested.json').writeAsString('{}');
  await fileSystem.file('outside.json').create(recursive: true);
  return fileSystem;
}

Future<FileSystemExplorer> _newExplorer({bool isReadOnly = false}) async =>
    FileSystemExplorer(
      fileSystem: await _newFileSystem(),
      rootPath: 'root',
      isReadOnly: isReadOnly,
    );

void main() {
  group('entry kind', () {
    test('reads the kind from the extension', () {
      expect(fileSystemEntryKindOf('a.json'), FileSystemEntryKind.json);
      expect(fileSystemEntryKindOf('a.yaml'), FileSystemEntryKind.yaml);
      expect(fileSystemEntryKindOf('a.yml'), FileSystemEntryKind.yaml);
      expect(fileSystemEntryKindOf('a.db'), FileSystemEntryKind.database);
      expect(fileSystemEntryKindOf('a.txt'), FileSystemEntryKind.text);
      expect(fileSystemEntryKindOf('LICENSE'), FileSystemEntryKind.text);
      expect(fileSystemEntryKindOf('a.png'), FileSystemEntryKind.binary);
    });
  });

  group('listing', () {
    test('lists directories first, then files by name', () async {
      var explorer = await _newExplorer();
      var entries = await explorer.list();
      expect(entries.map((entry) => entry.name), [
        'sub',
        'config.json',
        'notes.txt',
        'settings.yaml',
      ]);
      expect(entries.first.isDirectory, isTrue);
      expect(entries.map((entry) => entry.kind), [
        FileSystemEntryKind.directory,
        FileSystemEntryKind.json,
        FileSystemEntryKind.text,
        FileSystemEntryKind.yaml,
      ]);
      expect(entries[1].size, 15);
    });

    test('lists a sub directory', () async {
      var explorer = await _newExplorer();
      var entries = await explorer.list('sub');
      expect(entries.single.path, 'sub/nested.json');
      expect(entries.single.name, 'nested.json');
    });

    test('answers nothing for a directory that is not there', () async {
      var explorer = await _newExplorer();
      expect(await explorer.list('nope'), isEmpty);
      expect(await explorer.entry('nope'), isNull);
    });

    test('describes one entry', () async {
      var explorer = await _newExplorer();
      var entry = (await explorer.entry('config.json'))!;
      expect(entry.kind, FileSystemEntryKind.json);
      expect(entry.isObject, isTrue);
      expect(entry.size, 15);
    });

    test('refuses a path leaving the root', () async {
      var explorer = await _newExplorer();
      expect(
        () => explorer.fsPath('../outside.json'),
        throwsA(isA<FileSystemExplorerPathException>()),
      );
      expect(
        () => explorer.fsPath('/etc/passwd'),
        throwsA(isA<FileSystemExplorerPathException>()),
      );
      // A path that comes back inside is fine.
      expect(explorer.fsPath('sub/../config.json'), 'root/config.json');
    });
  });

  group('documents', () {
    test('edits a json document through the object editor', () async {
      var explorer = await _newExplorer();
      var sourceEditor = ObjectSourceEditor(
        explorer.objectSource('config.json'),
      );
      var editor = await sourceEditor.load();
      expect(editor.value, {'name': 'test'});
      editor.addField(ObjectPath.root, 'count', value: 2);
      await sourceEditor.save();
      expect(await explorer.readAsString('config.json'), '''
{
  "name": "test",
  "count": 2
}
''');
    });

    test('edits a yaml document in place', () async {
      var explorer = await _newExplorer();
      var sourceEditor = ObjectSourceEditor(
        explorer.objectSource('settings.yaml'),
      );
      var editor = await sourceEditor.load();
      editor.setValueAt(ObjectPath.root.field('count'), 2);
      await sourceEditor.save();
      expect(await explorer.readAsString('settings.yaml'), '''
# kept
count: 2
''');
    });
  });

  group('read only', () {
    test('refuses every write', () async {
      var explorer = await _newExplorer(isReadOnly: true);
      expect(
        explorer.createDirectory('new'),
        throwsA(isA<ReadOnlyException>()),
      );
      expect(
        explorer.createFile('new.json'),
        throwsA(isA<ReadOnlyException>()),
      );
      expect(
        explorer.writeAsString('config.json', '{}'),
        throwsA(isA<ReadOnlyException>()),
      );
      expect(explorer.delete('config.json'), throwsA(isA<ReadOnlyException>()));
      expect(
        explorer.rename('config.json', 'other.json'),
        throwsA(isA<ReadOnlyException>()),
      );
      // Reading still works.
      expect((await explorer.list()).length, 4);
    });

    test('hands out read only object sources', () async {
      var explorer = await _newExplorer(isReadOnly: true);
      var source = explorer.objectSource('config.json');
      expect(source.isReadOnly, isTrue);
      var sourceEditor = ObjectSourceEditor(source);
      var editor = await sourceEditor.load();
      editor.addField(ObjectPath.root, 'count', value: 2);
      expect(sourceEditor.save(), throwsA(isA<ReadOnlyException>()));
    });

    test('makes a read only view of a writable explorer', () async {
      var explorer = await _newExplorer();
      var readOnly = explorer.readOnly;
      expect(readOnly.isReadOnly, isTrue);
      expect(readOnly.rootPath, explorer.rootPath);
      // Already read only: it is its own read only view.
      expect(readOnly.readOnly, same(readOnly));
      expect(explorer.isReadOnly, isFalse);
    });
  });

  group('writing', () {
    test('creates a directory and a file', () async {
      var explorer = await _newExplorer();
      await explorer.createDirectory('made/up');
      await explorer.createFile('made/up/new.json', content: '{"a":1}');
      expect((await explorer.list('made/up')).single.name, 'new.json');
      expect(await explorer.readAsString('made/up/new.json'), '{"a":1}');
      expect(
        explorer.createFile('made/up/new.json'),
        throwsA(isA<StateError>()),
      );
    });

    test('renames and deletes', () async {
      var explorer = await _newExplorer();
      var renamed = await explorer.rename('config.json', 'renamed.json');
      expect(renamed.path, 'renamed.json');
      expect(await explorer.entry('config.json'), isNull);

      await explorer.delete('renamed.json');
      expect(await explorer.entry('renamed.json'), isNull);

      await explorer.delete('sub');
      expect(await explorer.entry('sub'), isNull);
    });

    test('refuses to rename to a path', () async {
      var explorer = await _newExplorer();
      expect(
        explorer.rename('config.json', 'a/b.json'),
        throwsA(isA<FileSystemExplorerPathException>()),
      );
    });

    test('an explorer rooted at a sub directory stays in it', () async {
      var explorer = (await _newExplorer()).sub('sub');
      expect((await explorer.list()).single.name, 'nested.json');
      expect(
        () => explorer.fsPath('../config.json'),
        throwsA(isA<FileSystemExplorerPathException>()),
      );
    });
  });

  group('databases', () {
    test('opens a sembast database file it listed', () async {
      var fileSystem = newFileSystemMemory();
      var factory = getDatabaseFactoryFsShim(fileSystem);
      var store = sembast.stringMapStoreFactory.store('config');
      var database = await factory.openDatabase('root/data.db');
      await store.record('main').put(database, {'name': 'test'});
      await database.close();

      var explorer = FileSystemExplorer(
        fileSystem: fileSystem,
        rootPath: 'root',
      );
      var entry = (await explorer.list()).single;
      expect(entry.name, 'data.db');
      expect(entry.isDatabase, isTrue);

      expect(
        await explorer.databaseKind('data.db'),
        FileSystemDatabaseKind.sembast,
      );
      var opened = await explorer.openDatabase('data.db');
      expect(opened.kind, FileSystemDatabaseKind.sembast);
      var collections = await opened.repository.listCollections();
      expect(collections.map((collection) => collection.name), ['config']);
      expect(await collections.single.listIds(), ['main']);

      var editor = await ObjectSourceEditor(
        collections.single.source('main'),
      ).load();
      expect(editor.value, {'name': 'test'});
      await opened.close();
    });

    test('opens an sdb database file it listed', () async {
      var fileSystem = newFileSystemMemory();
      var store = SdbStoreRef<String, SdbModel>('items');
      var database = await getSdbFactoryFsShim(fileSystem).openDatabase(
        'root/sdb.db',
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [store.schema()]),
        ),
      );
      await store.record('main').put(database, {'name': 'sdb'});
      await database.close();

      var explorer = FileSystemExplorer(
        fileSystem: fileSystem,
        rootPath: 'root',
      );
      expect(await explorer.databaseKind('sdb.db'), FileSystemDatabaseKind.sdb);
      var opened = await explorer.openDatabase('sdb.db');
      expect(opened.kind, FileSystemDatabaseKind.sdb);
      var collections = await opened.repository.listCollections();
      expect(collections.map((collection) => collection.name), ['items']);
      expect(await collections.single.listIds(), ['main']);

      var editor = await ObjectSourceEditor(
        collections.single.source('main'),
      ).load();
      expect(editor.value, {'name': 'sdb'});
      await opened.close();
    });

    test('answers no kind for a file that is not a database', () async {
      var explorer = await _newExplorer();
      expect(await explorer.databaseKind('notes.txt'), isNull);
      expect(await explorer.databaseKind('nope.db'), isNull);
    });
  });
}

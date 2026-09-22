import 'dart:typed_data';

import 'package:cv/cv.dart';
import 'package:festenao_common/data/object_editor.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:idb_shim/sdb.dart';
import 'package:sembast/sembast_memory.dart' as sembast;
import 'package:sembast/timestamp.dart' as sembast;
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:test/test.dart';

void main() {
  group('type registry', () {
    test('types the basic values', () {
      var registry = defaultObjectTypeRegistry;
      expect(registry.typeOf('text'), objectTypeString);
      expect(registry.typeOf(1), objectTypeInt);
      expect(registry.typeOf(1.5), objectTypeDouble);
      expect(registry.typeOf(true), objectTypeBool);
      expect(registry.typeOf(null), objectTypeNull);
      expect(registry.typeOf(<String, Object?>{}), objectTypeMap);
      expect(registry.typeOf(<Object?>[]), objectTypeList);
      expect(registry.typeOf(DateTime.now()), objectTypeDateTime);
      expect(registry.typeOf(Uint8List(0)), objectTypeBytes);
      expect(registry.typeOf(Duration.zero), objectTypeUnknown);
    });

    test('round trips the custom values through json', () {
      var registry = defaultObjectTypeRegistry;
      var value = {
        'when': DateTime.utc(2024, 1, 2, 3, 4, 5),
        'bytes': Uint8List.fromList([1, 2, 3]),
        'nested': [
          {'when': DateTime.utc(2025)},
        ],
      };
      var jsonValue = registry.toJsonEncodable(value);
      expect(jsonValue, {
        'when': {r'$dateTime': '2024-01-02T03:04:05.000Z'},
        'bytes': {r'$blob': 'AQID'},
        'nested': [
          {
            'when': {r'$dateTime': '2025-01-01T00:00:00.000Z'},
          },
        ],
      });
      expect(registry.fromJsonEncodable(jsonValue), value);
    });

    test('escapes a map that looks encoded', () {
      var registry = defaultObjectTypeRegistry;
      var value = {r'$dateTime': 'not a date'};
      var jsonValue = registry.toJsonEncodable(value);
      expect(registry.fromJsonEncodable(jsonValue), value);
    });

    test('keeps an unknown encoded value as is', () {
      var registry = ObjectTypeRegistry.basic();
      var jsonValue = {
        'when': {r'$timestamp': '2024-01-02T03:04:05.000Z'},
      };
      expect(registry.fromJsonEncodable(jsonValue), jsonValue);
    });
  });

  group('editor', () {
    test('edits a map', () {
      var editor = ObjectEditor({'name': 'test', 'count': 1});
      editor.setValueAt(ObjectPath.root.field('count'), 2);
      editor.addField(ObjectPath.root, 'enabled', typeId: objectTypeBool.id);
      editor.renameField(ObjectPath.root.field('name'), 'title');
      expect(editor.value, {'count': 2, 'enabled': false, 'title': 'test'});
      expect(editor.isDirty, isTrue);
      editor.markClean();
      expect(editor.isDirty, isFalse);
    });

    test('does not touch the value it was given', () {
      var value = {'count': 1};
      var editor = ObjectEditor(value);
      editor.setValueAt(ObjectPath.root.field('count'), 2);
      expect(value, {'count': 1});
    });

    test('edits a nested list', () {
      var editor = ObjectEditor({
        'items': [
          {'id': 'a'},
          {'id': 'b'},
        ],
      });
      var items = ObjectPath.root.field('items');
      editor.setValueAt(items.item(0).field('id'), 'a2');
      editor.addItem(items, index: 1, typeId: objectTypeString.id);
      editor.setValueAt(items.item(1), 'inserted');
      editor.removeAt(items.item(2));
      expect(editor.value, {
        'items': [
          {'id': 'a2'},
          'inserted',
        ],
      });
    });

    test('switches a type', () {
      var editor = ObjectEditor({'count': '1'});
      var count = ObjectPath.root.field('count');
      expect(editor.typeAt(count), objectTypeString);
      editor.setTypeAt(count, objectTypeInt.id);
      expect(editor.value, {'count': 0});
      editor.setTextAt(count, '42');
      expect(editor.value, {'count': 42});
    });

    test('lists the children of a node', () {
      var editor = ObjectEditor({
        'a': 1,
        'b': [true],
      });
      var children = editor.rootNode.children;
      expect(children.map((child) => child.name), ['a', 'b']);
      expect(children.last.children.single.name, '[0]');
      expect(children.last.children.single.display, 'true');
    });

    test('keeps a blob whole, list of bytes though it is', () {
      var bytes = Uint8List.fromList([1, 2, 3]);
      var editor = ObjectEditor({
        'data': bytes,
        'nested': [
          {'data': bytes},
        ],
      });
      var data = ObjectPath.root.field('data');
      expect(editor.typeAt(data), objectTypeBytes);
      expect(editor.valueAt(data), bytes);
      // One value, not three bytes.
      expect(editor.nodeAt(data)!.children, isEmpty);
      expect(editor.nodeAt(data)!.display, '<3 bytes>');
      expect(
        editor.valueAt(ObjectPath.root.field('nested').item(0).field('data')),
        bytes,
      );
      expect(editor.toJsonEncodable(), {
        'data': {r'$blob': 'AQID'},
        'nested': [
          {
            'data': {r'$blob': 'AQID'},
          },
        ],
      });
    });

    test('records nothing when a value is set to what it already is', () {
      var editor = ObjectEditor({
        'a': 1,
        'nested': {'b': 2},
      });
      var a = ObjectPath.root.field('a');
      editor.setValueAt(a, 1);
      expect(editor.isDirty, isFalse);
      expect(editor.operations, isEmpty);

      // A nested value compares by what it holds, not by identity.
      editor.setValueAt(ObjectPath.root.field('nested'), {'b': 2});
      expect(editor.isDirty, isFalse);

      // A real change still registers, once.
      editor.setValueAt(a, 2);
      expect(editor.operations.length, 1);

      // And a field that is not there yet is added even holding null, a
      // missing path being nothing like an unchanged one.
      editor.addField(ObjectPath.root, 'empty');
      expect(editor.value, containsPair('empty', isNull));
      expect(editor.operations.length, 2);
    });

    test('records the operations', () {
      var editor = ObjectEditor({'a': 1});
      editor.setValueAt(ObjectPath.root.field('a'), 2);
      editor.addField(ObjectPath.root, 'b');
      editor.removeAt(ObjectPath.root.field('a'));
      expect(editor.operations.map((operation) => '$operation'), [
        'set a',
        'set b',
        'remove a',
      ]);
    });
  });

  group('text format', () {
    test('round trips json', () {
      var value = {'name': 'test', 'when': DateTime.utc(2024)};
      var text = objectJsonFormat.encode(value);
      expect(text, '''
{
  "name": "test",
  "when": {
    "\$dateTime": "2024-01-01T00:00:00.000Z"
  }
}
''');
      expect(objectJsonFormat.decode(text), value);
    });

    test('round trips yaml', () {
      var value = {
        'name': 'test',
        'items': [1, 2],
      };
      var text = objectYamlFormat.encode(value);
      expect(objectYamlFormat.decode(text), value);
    });

    test('keeps the comments of a yaml file it edits', () {
      var source = '''
# The name of the thing
name: test
# How many
count: 1
items:
  - a
  - b
''';
      var editor = ObjectEditor(objectYamlFormat.decode(source));
      editor.setValueAt(ObjectPath.root.field('count'), 2);
      editor.addItem(ObjectPath.root.field('items'), value: 'c');
      var text = objectYamlFormat.encodeFrom(
        source,
        editor.value,
        operations: editor.operations,
      );
      expect(text, '''
# The name of the thing
name: test
# How many
count: 2
items:
  - a
  - b
  - c
''');
    });

    test('finds a format from a path', () {
      expect(objectTextFormatOf('a/b.json'), objectJsonFormat);
      expect(objectTextFormatOf('a/b.yaml'), objectYamlFormat);
      expect(objectTextFormatOf('a/b.yml'), objectYamlFormat);
      expect(objectTextFormatOf('a/b.txt'), isNull);
    });
  });

  group('cv', () {
    test('describes the fields a model declares', () {
      var schema = cvObjectSchema(_Settings());
      expect(schema.fields.map((field) => '$field'), [
        'name: string',
        'count: int',
        'enabled: bool',
        'tags: List<String>',
      ]);
      expect(schema.field('count')!.typeId, objectTypeInt.id);
      // A typed list has no basic editor type, the value names itself.
      expect(schema.field('tags')!.typeId, isNull);
      expect(schema.missingFieldNames({'name': 'a'}), [
        'count',
        'enabled',
        'tags',
      ]);
    });

    test('edits a model as the map it serializes to', () async {
      var settings = _Settings()
        ..name.v = 'test'
        ..count.v = 1;
      var source = CvObjectSource(settings);
      var sourceEditor = ObjectSourceEditor(source);
      var editor = await sourceEditor.load();
      expect(editor.value, {'name': 'test', 'count': 1});
      editor.setValueAt(ObjectPath.root.field('count'), 2);
      editor.addField(ObjectPath.root, 'enabled', value: true);
      await sourceEditor.save();
      expect(settings.count.v, 2);
      expect(settings.enabled.v, isTrue);
    });

    test('reads a tree back as a model', () {
      var editor = ObjectEditor({'name': 'test', 'count': 3});
      var settings = editor.toCvModel(_Settings());
      expect(settings.name.v, 'test');
      expect(settings.count.v, 3);
    });
  });

  group('sources', () {
    test('edits a yaml file through fs_shim, keeping its comments', () async {
      var fs = newFileSystemMemory();
      var file = fs.file('config.yaml');
      await file.writeAsString('''
# The name of the thing
name: test
count: 1 # how many
''');
      var source = FsObjectSource(file);
      expect(source.format, objectYamlFormat);
      var sourceEditor = ObjectSourceEditor(source);
      var editor = await sourceEditor.load();
      expect(editor.value, {'name': 'test', 'count': 1});
      editor.setValueAt(ObjectPath.root.field('count'), 2);
      await sourceEditor.save();
      expect(await file.readAsString(), '''
# The name of the thing
name: test
count: 2 # how many
''');
      expect(editor.isDirty, isFalse);
    });

    test('appends a new yaml field', () async {
      var fs = newFileSystemMemory();
      var file = fs.file('config.yaml');
      await file.writeAsString('''
name: test # the name
enabled: true
''');
      var sourceEditor = ObjectSourceEditor(FsObjectSource(file));
      var editor = await sourceEditor.load();
      editor.addField(ObjectPath.root, 'count', typeId: objectTypeInt.id);
      await sourceEditor.save();
      expect(await file.readAsString(), '''
name: test # the name
enabled: true
count: 0
''');
    });

    test('creates a json file that does not exist yet', () async {
      var fs = newFileSystemMemory();
      var source = FsObjectSource(fs.file('sub/dir/new.json'));
      var sourceEditor = ObjectSourceEditor(source);
      var editor = await sourceEditor.load();
      expect(editor.value, <String, Object?>{});
      editor.addField(ObjectPath.root, 'name', value: 'test');
      await sourceEditor.save();
      expect(await fs.file('sub/dir/new.json').readAsString(), '''
{
  "name": "test"
}
''');
    });

    test('lists the files of a directory', () async {
      var fs = newFileSystemMemory();
      await fs.file('dir/a.json').create(recursive: true);
      await fs.file('dir/b.json').create(recursive: true);
      await fs.file('dir/c.txt').create(recursive: true);
      var collection = FsObjectCollection(fs.directory('dir'));
      expect(await collection.listIds(), ['a', 'b']);
      expect(collection.source('a').title, 'dir/a.json');
    });

    test('edits a sembast record', () async {
      var db = await sembast.databaseFactoryMemory.openDatabase('test.db');
      var store = sembast.stringMapStoreFactory.store('config');
      await store.record('main').put(db, {
        'name': 'test',
        'when': sembast.Timestamp.parse('2024-01-01T00:00:00.000Z'),
      });
      var source = SembastObjectSource(database: db, store: store, key: 'main');
      expect(source.typeRegistry, sembastObjectTypeRegistry);
      var sourceEditor = ObjectSourceEditor(source);
      var editor = await sourceEditor.load();
      var when = ObjectPath.root.field('when');
      expect(editor.typeAt(when).id, 'timestamp');
      editor.setTextAt(when, '2025-02-03T00:00:00.000Z');
      await sourceEditor.save();
      expect(
        (await store.record('main').get(db))!['when'],
        sembast.Timestamp.parse('2025-02-03T00:00:00.000Z'),
      );
      await db.close();
    });

    test('lists the stores of a sembast database', () async {
      var db = await sembast.databaseFactoryMemory.openDatabase('stores.db');
      await sembast.stringMapStoreFactory.store('config').record('main').put(
        db,
        {'a': 1},
      );
      var repository = SembastObjectRepository(db);
      var collections = await repository.listCollections();
      expect(collections.map((collection) => collection.name), ['config']);
      expect(await collections.single.listIds(), ['main']);
      await db.close();
    });

    test('edits an sdb record', () async {
      var store = SdbStoreRef<String, SdbModel>('config');
      var db = await sdbFactoryMemory.openDatabase(
        'object_editor_test.db',
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [store.schema()]),
        ),
      );
      await store.record('main').put(db, {
        'name': 'test',
        'when': SdbTimestamp.parse('2024-01-01T00:00:00.000Z'),
      });
      var source = SdbObjectSource(database: db, store: store, key: 'main');
      var sourceEditor = ObjectSourceEditor(source);
      var editor = await sourceEditor.load();
      var when = ObjectPath.root.field('when');
      expect(editor.typeAt(when).id, 'timestamp');
      editor.setTextAt(when, '2025-02-03T00:00:00.000Z');
      editor.addField(ObjectPath.root, 'count', value: 3);
      await sourceEditor.save();
      expect(await store.record('main').getValue(db), {
        'name': 'test',
        'when': SdbTimestamp.parse('2025-02-03T00:00:00.000Z'),
        'count': 3,
      });

      var repository = SdbObjectRepository(db);
      var collections = await repository.listCollections();
      expect(collections.map((collection) => collection.name), ['config']);
      expect(await collections.single.listIds(), ['main']);
      await db.close();
    });

    test('edits a firestore document', () async {
      // ignore: deprecated_member_use
      var firestore = newFirestoreMemory();
      await firestore.doc('config/main').set({
        'name': 'test',
        'when': Timestamp.parse('2024-01-01T00:00:00.000Z'),
      });
      var source = FirestoreObjectSource(
        firestore: firestore,
        path: 'config/main',
      );
      var sourceEditor = ObjectSourceEditor(source);
      var editor = await sourceEditor.load();
      var when = ObjectPath.root.field('when');
      expect(editor.typeAt(when).id, 'timestamp');
      editor.setTextAt(when, '2025-02-03T00:00:00.000Z');
      await sourceEditor.save();
      expect(
        (await firestore.doc('config/main').get()).data['when'],
        Timestamp.parse('2025-02-03T00:00:00.000Z'),
      );

      var collection = FirestoreObjectCollection(
        firestore: firestore,
        path: 'config',
      );
      expect(await collection.listIds(), ['main']);
    });

    test('edits a value in memory', () async {
      var source = MemoryObjectSource(value: {'a': 1});
      var sourceEditor = ObjectSourceEditor(source);
      var editor = await sourceEditor.load();
      editor.setValueAt(ObjectPath.root.field('a'), 2);
      await sourceEditor.save();
      expect(await source.read(), {'a': 2});
      await source.close();
    });
  });
}

/// A model, for the cv tests.
class _Settings extends CvModelBase {
  final name = CvField<String>('name');
  final count = CvField<int>('count');
  final enabled = CvField<bool>('enabled');
  final tags = CvListField<String>('tags');

  @override
  CvFields get fields => [name, count, enabled, tags];
}

import 'dart:typed_data';

import 'package:cv/cv.dart';
import 'package:festenao_common/data/object_editor.dart';
import 'package:idb_shim/sdb.dart';
import 'package:sembast/sembast_memory.dart' as sembast;
import 'package:sembast/timestamp.dart' as sembast;
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:test/test.dart';

void main() {
  group('clipboard', () {
    test('copies and pastes a whole tree', () {
      var clipboard = ObjectClipboard();
      var from = ObjectEditor({'name': 'test', 'count': 1});
      var data = from.copyAt(ObjectPath.root, clipboard: clipboard);
      expect(data.label, '/');

      var to = ObjectEditor(<String, Object?>{});
      expect(to.canPaste(clipboard: clipboard), isTrue);
      to.pasteAt(ObjectPath.root, clipboard: clipboard);
      expect(to.value, {'name': 'test', 'count': 1});
    });

    test('copies and pastes a sub object', () {
      var clipboard = ObjectClipboard();
      var editor = ObjectEditor({
        'a': {'nested': true},
        'b': <String, Object?>{},
      });
      editor.copyAt(ObjectPath.root.field('a'), clipboard: clipboard);
      editor.pasteAsField(
        ObjectPath.root.field('b'),
        'copied',
        clipboard: clipboard,
      );
      expect(editor.value, {
        'a': {'nested': true},
        'b': {
          'copied': {'nested': true},
        },
      });
    });

    test('copies and pastes a list item', () {
      var clipboard = ObjectClipboard();
      var editor = ObjectEditor({
        'items': ['a', 'b'],
      });
      var items = ObjectPath.root.field('items');
      var data = editor.copyAt(items.item(1), clipboard: clipboard);
      expect(data.label, 'items[1]');
      editor.pasteAsItem(items, index: 0, clipboard: clipboard);
      expect(editor.value, {
        'items': ['b', 'a', 'b'],
      });
    });

    test('the pasted value is a copy, not the same tree', () {
      var clipboard = ObjectClipboard();
      var editor = ObjectEditor({
        'a': {'nested': 1},
        'b': <String, Object?>{},
      });
      editor.copyAt(ObjectPath.root.field('a'), clipboard: clipboard);
      editor.pasteAsField(
        ObjectPath.root.field('b'),
        'copy',
        clipboard: clipboard,
      );
      editor.setValueAt(
        ObjectPath.root.field('b').field('copy').field('nested'),
        2,
      );
      expect(editor.valueAt(ObjectPath.root.field('a').field('nested')), 1);
    });

    test('carries a custom value across backends', () {
      var clipboard = ObjectClipboard();
      // Copied out of a sembast record, where a date is a sembast Timestamp.
      var sembastEditor = ObjectEditor({
        'when': sembast.Timestamp.parse('2024-01-02T03:04:05.000Z'),
      }, typeRegistry: sembastObjectTypeRegistry);
      var data = sembastEditor.copyAt(
        ObjectPath.root.field('when'),
        clipboard: clipboard,
      );
      expect(data.jsonValue, {r'$timestamp': '2024-01-02T03:04:05.000Z'});

      // Pasted into a plain json document, where a date is a DateTime.
      var jsonEditor = ObjectEditor(<String, Object?>{});
      jsonEditor.pasteAsField(ObjectPath.root, 'when', clipboard: clipboard);
      expect(
        jsonEditor.valueAt(ObjectPath.root.field('when')),
        DateTime.utc(2024, 1, 2, 3, 4, 5),
      );
    });

    test('goes through json text, for the clipboard of the system', () {
      var clipboard = ObjectClipboard();
      var editor = ObjectEditor({
        'when': DateTime.utc(2024),
        'data': Uint8List.fromList([1, 2, 3]),
      });
      var text = editor.copyAt(ObjectPath.root, clipboard: clipboard).text;
      expect(text, '''
{
  "when": {
    "\$dateTime": "2024-01-01T00:00:00.000Z"
  },
  "data": {
    "\$blob": "AQID"
  }
}
''');

      var parsed = ObjectClipboardData.tryParse(text)!;
      expect(parsed.value(defaultObjectTypeRegistry), editor.value);
      expect(ObjectClipboardData.tryParse('not json'), isNull);
    });

    test('refuses to paste when nothing was copied', () {
      var clipboard = ObjectClipboard();
      var editor = ObjectEditor(<String, Object?>{});
      expect(editor.canPaste(clipboard: clipboard), isFalse);
      expect(
        () => editor.pasteAt(ObjectPath.root, clipboard: clipboard),
        throwsA(isA<StateError>()),
      );
    });

    test('fires when something is copied', () async {
      var clipboard = ObjectClipboard();
      var events = <ObjectClipboardData?>[];
      var subscription = clipboard.onChanged.listen(events.add);
      ObjectEditor({'a': 1}).copyAt(ObjectPath.root, clipboard: clipboard);
      clipboard.clear();
      await Future<void>.delayed(Duration.zero);
      expect(events.length, 2);
      expect(events.first!.jsonValue, {'a': 1});
      expect(events.last, isNull);
      await subscription.cancel();
      await clipboard.close();
    });

    test('copies a whole object and pastes it into another source', () async {
      var clipboard = ObjectClipboard();
      var from = MemoryObjectSource(title: 'from', value: {'a': 1});
      var to = MemoryObjectSource(title: 'to');
      var data = await from.copy(clipboard: clipboard);
      expect(data.label, 'from');
      await to.paste(clipboard: clipboard);
      expect(await to.read(), {'a': 1});
      await from.close();
      await to.close();
    });

    test('pastes a whole object as a new record of a collection', () async {
      var clipboard = ObjectClipboard();
      var database = await sembast.databaseFactoryMemory.openDatabase(
        'clipboard.db',
      );
      var collection = SembastObjectCollection(
        database: database,
        store: sembast.stringMapStoreFactory.store('config'),
      );
      ObjectEditor(
        {'name': 'copied'},
        typeRegistry: collection.typeRegistry,
      ).copyAt(ObjectPath.root, clipboard: clipboard);

      var id = await collection.paste(clipboard: clipboard, id: 'pasted');
      expect(id, 'pasted');
      expect(await collection.source('pasted').read(), {'name': 'copied'});
      await database.close();
    });
  });

  group('read only', () {
    test('a memory source refuses writes', () async {
      var source = MemoryObjectSource(value: {'a': 1}, isReadOnly: true);
      expect(source.write({'a': 2}), throwsA(isA<ReadOnlyException>()));
      expect(source.delete(), throwsA(isA<ReadOnlyException>()));
      expect(await source.read(), {'a': 1});
      await source.close();
    });

    test('a sembast store refuses writes down to its sources', () async {
      var database = await sembast.databaseFactoryMemory.openDatabase('ro.db');
      var store = sembast.stringMapStoreFactory.store('config');
      await store.record('main').put(database, {'a': 1});

      var repository = SembastObjectRepository(database, isReadOnly: true);
      expect(repository.isReadOnly, isTrue);
      var collection = (await repository.listCollections()).single;
      expect(collection.isReadOnly, isTrue);
      expect(collection.add({'a': 2}), throwsA(isA<ReadOnlyException>()));

      var source = collection.source('main');
      expect(source.isReadOnly, isTrue);
      expect(await source.read(), {'a': 1});
      expect(source.write({'a': 2}), throwsA(isA<ReadOnlyException>()));
      expect(source.delete(), throwsA(isA<ReadOnlyException>()));
      await database.close();
    });

    test('an sdb store refuses writes down to its sources', () async {
      var store = SdbStoreRef<String, SdbModel>('items');
      var database = await sdbFactoryMemory.openDatabase(
        'ro_sdb.db',
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [store.schema()]),
        ),
      );
      await store.record('main').put(database, {'a': 1});

      var repository = SdbObjectRepository(database, isReadOnly: true);
      var collection = (await repository.listCollections()).single;
      expect(collection.isReadOnly, isTrue);
      var source = collection.source('main');
      expect(await source.read(), {'a': 1});
      expect(source.write({'a': 2}), throwsA(isA<ReadOnlyException>()));
      await database.close();
    });

    test('a firestore collection refuses writes down to its sources', () async {
      var collection = FirestoreObjectCollection(
        // ignore: deprecated_member_use
        firestore: newFirestoreMemory(),
        path: 'config',
        isReadOnly: true,
      );
      var source = collection.source('main');
      expect(source.isReadOnly, isTrue);
      expect(source.write({'a': 1}), throwsA(isA<ReadOnlyException>()));
      expect(collection.add({'a': 1}), throwsA(isA<ReadOnlyException>()));
    });

    test('a cv source refuses writes', () async {
      var source = CvObjectSource(CvMapModel(), isReadOnly: true);
      expect(source.write({'a': 1}), throwsA(isA<ReadOnlyException>()));
    });

    test('a source editor refuses to save a read only source', () async {
      var source = MemoryObjectSource(value: {'a': 1}, isReadOnly: true);
      var sourceEditor = ObjectSourceEditor(source);
      var editor = await sourceEditor.load();
      editor.setValueAt(ObjectPath.root.field('a'), 2);
      expect(sourceEditor.save(), throwsA(isA<ReadOnlyException>()));
      await source.close();
    });
  });
}

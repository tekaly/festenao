import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:idb_shim/sdb.dart';
import 'package:sembast/sembast.dart' as sembast;

Future<FileSystem> _newFileSystem() async {
  var fileSystem = newFileSystemMemory();
  await fileSystem.file('root/config.json').create(recursive: true);
  await fileSystem.file('root/config.json').writeAsString('{"name":"test"}');
  await fileSystem.file('root/notes.txt').create(recursive: true);
  await fileSystem.file('root/notes.txt').writeAsString('hello');
  await fileSystem.directory('root/sub').create(recursive: true);
  return fileSystem;
}

/// The file system is really asynchronous — `fs_shim` memory is `idb_shim`
/// over sembast — and `testWidgets` runs in a fake async zone where those
/// futures never complete. Everything here runs in [WidgetTester.runAsync],
/// where timers are the real ones, and settles by pumping between real
/// delays: `pumpAndSettle` is not allowed in that zone.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Opens the row menu of the entry named [name], whatever row it sits on.
Future<void> _openMenu(WidgetTester tester, String name) async {
  await tester.tap(
    find.descendant(
      of: find.widgetWithText(ListTile, name),
      matching: find.byIcon(Icons.more_vert),
    ),
  );
  await _settle(tester);
}

Future<void> _pump(WidgetTester tester, FileSystemExplorer explorer) async {
  await tester.pumpWidget(
    MaterialApp(home: FileSystemExplorerScreen(explorer: explorer)),
  );
  await _settle(tester);
}

/// A [testWidgets] whose body runs with real async, see [_settle].
void _testWidgets(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    await tester.runAsync(() => body(tester));
  });
}

void main() {
  group('FileSystemExplorerScreen', () {
    _testWidgets('lists the entries with an icon per kind', (tester) async {
      var explorer = FileSystemExplorer(
        fileSystem: await _newFileSystem(),
        rootPath: 'root',
      );
      await _pump(tester, explorer);

      expect(find.text('sub'), findsOneWidget);
      expect(find.text('config.json'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
      expect(find.byIcon(Icons.data_object), findsOneWidget);
      expect(find.text('15 B'), findsOneWidget);
    });

    _testWidgets('opens a json document in the object editor', (tester) async {
      var explorer = FileSystemExplorer(
        fileSystem: await _newFileSystem(),
        rootPath: 'root',
      );
      await _pump(tester, explorer);

      await tester.tap(find.text('config.json'));
      await _settle(tester);

      // The object editor, on the document.
      expect(find.text('name'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'edited');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.save));
      await _settle(tester);

      expect(
        await explorer.readAsString('config.json'),
        '{\n  "name": "edited"\n}\n',
      );
    });

    _testWidgets('opens a text file in the text editor', (tester) async {
      var explorer = FileSystemExplorer(
        fileSystem: await _newFileSystem(),
        rootPath: 'root',
      );
      await _pump(tester, explorer);

      await tester.tap(find.text('notes.txt'));
      await _settle(tester);
      expect(find.text('hello'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hello world');
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.save));
      await _settle(tester);

      expect(await explorer.readAsString('notes.txt'), 'hello world');
    });

    _testWidgets('walks into a directory', (tester) async {
      var fileSystem = await _newFileSystem();
      await fileSystem.file('root/sub/nested.json').create(recursive: true);
      await fileSystem.file('root/sub/nested.json').writeAsString('{}');
      var explorer = FileSystemExplorer(
        fileSystem: fileSystem,
        rootPath: 'root',
      );
      await _pump(tester, explorer);

      await tester.tap(find.text('sub'));
      await _settle(tester);
      expect(find.text('nested.json'), findsOneWidget);
      expect(find.text('config.json'), findsNothing);
    });

    _testWidgets('creates a folder and a json file', (tester) async {
      var explorer = FileSystemExplorer(
        fileSystem: await _newFileSystem(),
        rootPath: 'root',
      );
      await _pump(tester, explorer);

      await tester.tap(find.byIcon(Icons.add));
      await _settle(tester);
      await tester.tap(find.text('New folder'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'made');
      await tester.tap(find.text('Ok'));
      await _settle(tester);

      expect(find.text('made'), findsOneWidget);
      expect(await explorer.entry('made'), isNotNull);
    });

    _testWidgets('renames and deletes an entry', (tester) async {
      var explorer = FileSystemExplorer(
        fileSystem: await _newFileSystem(),
        rootPath: 'root',
      );
      await _pump(tester, explorer);

      await _openMenu(tester, 'config.json');
      await tester.tap(find.text('Rename'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'renamed.json');
      await tester.tap(find.text('Ok'));
      await _settle(tester);
      expect(find.text('renamed.json'), findsOneWidget);

      await _openMenu(tester, 'renamed.json');
      await tester.tap(find.text('Delete'));
      await _settle(tester);
      // The confirm dialog, whose title names the entry.
      expect(find.text('Delete renamed.json'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await _settle(tester);
      expect(find.text('renamed.json'), findsNothing);
    });

    _testWidgets('a read only explorer hides every write action', (
      tester,
    ) async {
      var explorer = FileSystemExplorer(
        fileSystem: await _newFileSystem(),
        rootPath: 'root',
        isReadOnly: true,
      );
      await _pump(tester, explorer);

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.text('config.json'), findsOneWidget);

      // The row menu is still there, offering the copy and nothing that
      // writes: reading includes taking a copy.
      await _openMenu(tester, 'config.json');
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Paste into'), findsNothing);
      expect(find.text('Rename'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);

      // The text editor it opens is read only too.
      await tester.tap(find.text('notes.txt'));
      await _settle(tester);
      expect(find.byIcon(Icons.save), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    });

    _testWidgets('opens a sembast database in the object explorer', (
      tester,
    ) async {
      var fileSystem = newFileSystemMemory();
      var store = sembast.stringMapStoreFactory.store('config');
      var database = await getDatabaseFactoryFsShim(
        fileSystem,
      ).openDatabase('root/data.db');
      await store.record('main').put(database, {'name': 'test'});
      await database.close();

      var explorer = FileSystemExplorer(
        fileSystem: fileSystem,
        rootPath: 'root',
      );
      await _pump(tester, explorer);
      expect(find.byIcon(Icons.storage_outlined), findsOneWidget);

      await tester.tap(find.text('data.db'));
      await _settle(tester);
      // The object explorer, on the stores of the database.
      expect(find.text('config'), findsOneWidget);

      await tester.tap(find.text('config'));
      await _settle(tester);
      expect(find.text('main'), findsOneWidget);

      await tester.tap(find.text('main'));
      await _settle(tester);
      expect(find.text('name'), findsOneWidget);
    });

    _testWidgets('opens an sdb database in the object explorer', (
      tester,
    ) async {
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
      await _pump(tester, explorer);

      await tester.tap(find.text('sdb.db'));
      await _settle(tester);
      expect(find.text('items'), findsOneWidget);

      await tester.tap(find.text('items'));
      await _settle(tester);
      await tester.tap(find.text('main'));
      await _settle(tester);
      expect(find.text('name'), findsOneWidget);
    });
  });
}

import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

/// See the file system explorer tests: real timers.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void _testWidgets(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    await tester.runAsync(() => body(tester));
  });
}

Future<FileSystemExplorer> _newExplorer() async {
  var fileSystem = newFileSystemMemory();
  await fileSystem.directory('root').create(recursive: true);
  return FileSystemExplorer(fileSystem: fileSystem, rootPath: 'root');
}

Future<void> _pump(
  WidgetTester tester,
  FileSystemExplorer explorer, {
  List<FileSystemCreateAction>? createActions,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FileSystemExplorerScreen(
        explorer: explorer,
        createActions: createActions,
      ),
    ),
  );
  await _settle(tester);
}

/// Picks [label] in the `+` menu.
Future<void> _create(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.add));
  await _settle(tester);
  await tester.tap(find.text(label));
  await _settle(tester);
}

/// A record of the app schema, declared with the `cv` sdb helpers.
class _AppNote extends ScvStringRecordBase {
  final title = CvField<String>('title');

  @override
  CvFields get fields => [title];
}

final _appNoteStore = scvStringStoreFactory.store<_AppNote>('app_note');

void main() {
  group('create actions', () {
    _testWidgets('the + menu offers what it is given', (tester) async {
      await _pump(
        tester,
        await _newExplorer(),
        createActions: [
          fileSystemCreateFileAction(label: 'New thing', extension: '.json'),
        ],
      );
      await tester.tap(find.byIcon(Icons.add));
      await _settle(tester);

      expect(find.text('New folder'), findsOneWidget);
      expect(find.text('New thing'), findsOneWidget);
      // What it was given replaces the built in ones.
      expect(find.text('New yaml file'), findsNothing);
    });

    _testWidgets('creates a sembast database and opens it', (tester) async {
      var explorer = await _newExplorer();
      var store = sembast.stringMapStoreFactory.store('config');
      await _pump(
        tester,
        explorer,
        createActions: [
          fileSystemCreateSembastDatabaseAction(
            onCreate: (database) =>
                store.record('main').put(database, {'a': 1}),
          ),
        ],
      );

      await _create(tester, 'New sembast database');
      await tester.enterText(find.byType(TextField), 'made');
      await tester.tap(find.text('Ok'));
      await _settle(tester);

      // It opened in the object explorer, on the store it was seeded with.
      expect(find.text('config'), findsOneWidget);
      expect(
        await explorer.databaseKind('made.db'),
        FileSystemDatabaseKind.sembast,
      );
    });

    _testWidgets('creates an sdb database from a cv schema', (tester) async {
      cvAddConstructor(_AppNote.new);
      var explorer = await _newExplorer();
      await _pump(
        tester,
        explorer,
        createActions: [
          fileSystemCreateSdbDatabaseAction(
            label: 'New notes database',
            schema: SdbDatabaseSchema(stores: [_appNoteStore.schema()]),
            onCreate: (database) => _appNoteStore
                .record('first')
                .put(database, _AppNote()..title.v = 'First'),
          ),
        ],
      );

      await _create(tester, 'New notes database');
      await tester.enterText(find.byType(TextField), 'notes');
      await tester.tap(find.text('Ok'));
      await _settle(tester);

      expect(find.text('app_note'), findsOneWidget);
      expect(
        await explorer.databaseKind('notes.db'),
        FileSystemDatabaseKind.sdb,
      );
    });

    _testWidgets('creates a binary file and opens the hex editor', (
      tester,
    ) async {
      await _pump(
        tester,
        await _newExplorer(),
        createActions: [
          fileSystemCreateBinaryFileAction(bytes: [0x48, 0x69]),
        ],
      );

      await _create(tester, 'New binary file');
      await tester.enterText(find.byType(TextField), 'data');
      await tester.tap(find.text('Ok'));
      await _settle(tester);

      expect(find.textContaining('|Hi|'), findsOneWidget);
    });
  });

  group('demos', () {
    _testWidgets('makes one of each kind and opens it', (tester) async {
      var explorer = await _newExplorer();
      await _pump(
        tester,
        explorer,
        createActions: festenaoFileSystemDemoActions(),
      );

      /// Back to the listing, the demo having opened what it made.
      Future<void> back() async {
        await tester.pageBack();
        await _settle(tester);
      }

      await _create(tester, 'Demo json document');
      expect(find.text('name'), findsOneWidget);
      // The date and the blob of the demo decoded into real values: a date
      // gets its picker, a blob edits as base64 rather than as a list of
      // ints.
      expect(find.text('when'), findsOneWidget);
      expect(find.byIcon(Icons.event), findsOneWidget);
      expect(find.text('data'), findsOneWidget);
      // The blob reads as base64 in its editor, so it decoded to bytes.
      expect(find.text('AQIDBA=='), findsOneWidget);
      await back();

      await _create(tester, 'Demo yaml document');
      expect(find.text('count'), findsOneWidget);
      expect(find.text('nested'), findsOneWidget);
      await back();

      await _create(tester, 'Demo text file');
      expect(find.textContaining('A demo text file.'), findsOneWidget);
      await back();

      await _create(tester, 'Demo binary file');
      expect(find.textContaining('|DEMO'), findsOneWidget);
      await back();

      await _create(tester, 'Demo sembast database');
      expect(find.text('settings'), findsOneWidget);
      expect(find.text('event'), findsOneWidget);
      await back();

      await _create(tester, 'Demo sdb database');
      expect(find.text('note'), findsOneWidget);
      expect(find.text('tag'), findsOneWidget);
      await back();

      // Each one landed as its own file.
      var names = (await explorer.list()).map((entry) => entry.name).toList();
      expect(names, [
        'demo.bin',
        'demo.json',
        'demo.txt',
        'demo.yaml',
        'demo_sdb.db',
        'demo_sembast.db',
      ]);
    });

    test('names a demo file that is not taken yet', () async {
      var explorer = await _newExplorer();
      expect(
        await fileSystemFreePath(
          explorer,
          directoryPath: '',
          name: 'demo',
          extension: '.json',
        ),
        'demo.json',
      );
      await explorer.createFile('demo.json');
      expect(
        await fileSystemFreePath(
          explorer,
          directoryPath: '',
          name: 'demo',
          extension: '.json',
        ),
        'demo_2.json',
      );
    });

    test('the demo sdb schema declares its stores and its index', () {
      var schema = demoSdbDatabaseSchema();
      expect(schema.stores.map((store) => store.name), ['note', 'tag']);
      expect(schema.stores.first.indexes.map((index) => index.name), ['title']);
    });
  });
}

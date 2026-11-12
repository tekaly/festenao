import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart' as sembast;

/// See the file system explorer tests: real timers.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
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
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<FileSystemExplorer> _newExplorer(String path, String content) async {
  var explorer = FileSystemExplorer(
    fileSystem: newFileSystemMemory(),
    rootPath: 'root',
  );
  await explorer.writeAsString(path, content);
  return explorer;
}

void main() {
  group('ObjectEditorScreen', () {
    _testWidgets('shows why a source cannot be read, and retries', (
      tester,
    ) async {
      var explorer = await _newExplorer('bad.json', 'not json {');
      await tester.pumpWidget(
        MaterialApp(
          home: ObjectEditorScreen(source: explorer.objectSource('bad.json')),
        ),
      );
      await _settle(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Retry'), findsOneWidget);

      // Fixed meanwhile: retry reads it.
      await explorer.writeAsString('bad.json', '{"name":"fixed"}');
      await tester.tap(find.text('Retry'));
      await _settle(tester);
      expect(find.text('name'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    _testWidgets('saves the value still being typed', (tester) async {
      var explorer = await _newExplorer('doc.json', '{"a":"1","b":"2"}');
      await tester.pumpWidget(
        MaterialApp(
          home: ObjectEditorScreen(source: explorer.objectSource('doc.json')),
        ),
      );
      await _settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'x');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);
      // Typed, neither submitted nor left: a touch on save (android does
      // not unfocus a field on a touch outside it).
      await tester.enterText(find.byType(TextField).at(1), 'y');
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.save));
      await _settle(tester);
      expect(
        await explorer.readAsString('doc.json'),
        '{\n  "a": "x",\n  "b": "y"\n}\n',
      );
    });
  });

  group('ObjectCollectionScreen', () {
    _testWidgets('says when the list is cut at the limit', (tester) async {
      var database = await sembast.newDatabaseFactoryMemory().openDatabase(
        'test.db',
      );
      var store = sembast.stringMapStoreFactory.store('note');
      for (var id in ['n1', 'n2', 'n3']) {
        await store.record(id).put(database, {'title': id});
      }
      var collection =
          (await SembastObjectRepository(
            database,
            title: 'test',
          ).listCollections()).singleWhere(
            (collection) => collection.name == 'note',
          );

      await tester.pumpWidget(
        MaterialApp(
          home: ObjectCollectionScreen(collection: collection, limit: 2),
        ),
      );
      await _settle(tester);
      expect(find.text('n1'), findsOneWidget);
      expect(find.text('n2'), findsOneWidget);
      expect(find.text('n3'), findsNothing);
      expect(find.text('2+ records'), findsOneWidget);
      expect(find.text('Only the first 2 records are listed'), findsOneWidget);

      // At the limit exactly: nothing cut.
      await tester.pumpWidget(
        MaterialApp(
          home: ObjectCollectionScreen(
            // A new screen, not the one before given a new limit.
            key: const ValueKey(3),
            collection: collection,
            limit: 3,
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('n3'), findsOneWidget);
      expect(find.text('3 records'), findsOneWidget);
      expect(find.textContaining('Only the first'), findsNothing);
      await database.close();
    });
  });
}

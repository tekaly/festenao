import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:festenao_dashboard_app_demo/main.dart';
import 'package:festenao_dashboard_app_demo/src/demo_data.dart';
import 'package:festenao_dashboard_app_demo/src/demo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// See the explorer tests: the backends are really asynchronous, so the demo
/// runs with real timers.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void _testWidgets(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    await tester.runAsync(() async {
      // The home page carries a theme picker above the menu, so the window
      // has to be tall enough for the last entry to be built.
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      try {
        await body(tester);
      } finally {
        await tester.binding.setSurfaceSize(null);
      }
    });
  });
}

void main() {
  group('the demo data', () {
    test('builds a firestore tree, documents and two databases', () async {
      var data = await DemoData.create();

      // Firestore: the collections, and a sub collection under a document.
      var collections = await data.firestore.listCollections();
      expect(collections.map((collection) => collection.id).toSet(), {
        'settings',
        'user',
        'event',
      });
      expect(
        (await data.firestore.doc('user/alice').listCollections()).map(
          (collection) => collection.id,
        ),
        ['note'],
      );

      // The file system: one document of each kind, and a sub directory.
      var entries = await data.explorer.list();
      expect(entries.map((entry) => entry.name), [
        'data',
        'sub',
        'config.json',
        'notes.txt',
        'picture.bin',
        'settings.yaml',
      ]);

      // The databases, one of each kind, found by walking the tree.
      var databases = await listFileSystemDatabases(data.explorer);
      expect(
        {for (var (entry, kind) in databases) entry.name: kind},
        {
          'sdb_demo.db': FileSystemDatabaseKind.sdb,
          'sembast_demo.db': FileSystemDatabaseKind.sembast,
        },
      );
    });

    test('is editable and loses the edits on a restart', () async {
      var data = await DemoData.create();
      expect(data.explorer.isReadOnly, isFalse);
      await data.explorer.writeAsString('config.json', '{"edited": true}');
      expect(
        await data.explorer.readAsString('config.json'),
        '{"edited": true}',
      );

      // A fresh start builds the demo content again, the edit gone with the
      // file system it was made in.
      var restarted = await DemoData.create();
      expect(
        await restarted.explorer.readAsString('config.json'),
        demoJsonContent,
      );
    });
  });

  group('the demo app', () {
    _testWidgets('offers every explorer, in order', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      var titles = find
          .descendant(of: find.byType(ListTile), matching: find.byType(Text))
          .evaluate()
          .map((element) => (element.widget as Text).data)
          .toList();
      expect(
        titles,
        containsAllInOrder([
          'Firestore explorer',
          'File system explorer',
          'Sdb explorer',
          'Sembast explorer',
        ]),
      );
    });

    _testWidgets('swaps the theme from the home screen', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      // Every theme is offered, the first one being on.
      for (var demoTheme in demoThemes()) {
        expect(find.text(demoTheme.name), findsWidgets);
      }
      var before = Theme.of(
        tester.element(find.text('Firestore explorer')),
      ).colorScheme;
      expect(before.brightness, Brightness.light);

      // The dark one is another brightness, and the explorers follow it
      // without a colour of their own.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Material dark'));
      await _settle(tester);
      var after = Theme.of(
        tester.element(find.text('Firestore explorer')),
      ).colorScheme;
      expect(after.brightness, Brightness.dark);
      expect(after.surface, isNot(before.surface));

      // And it carries into the screens it opens.
      await tester.tap(find.text('File system explorer'));
      await _settle(tester);
      expect(
        Theme.of(
          tester.element(find.text('config.json')),
        ).colorScheme.brightness,
        Brightness.dark,
      );
    });

    _testWidgets('offers the poppins themes', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      await tester.tap(
        find.widgetWithText(ChoiceChip, 'Festenao poppins dark'),
      );
      await _settle(tester);
      var theme = Theme.of(tester.element(find.text('Firestore explorer')));
      expect(theme.colorScheme.brightness, Brightness.dark);
      // The poppins themes carry the rules of themeData1: floating snack
      // bars, and a font family of their own.
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(theme.textTheme.bodyMedium?.fontFamily, isNotNull);
    });

    _testWidgets('opens the firestore explorer on the demo tree', (
      tester,
    ) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      await tester.tap(find.text('Firestore explorer'));
      await _settle(tester);
      expect(find.text('settings'), findsOneWidget);
      expect(find.text('user'), findsOneWidget);

      await tester.tap(find.text('settings'));
      await _settle(tester);
      await tester.tap(find.text('main'));
      await _settle(tester);
      // The document, with its types.
      expect(find.text('updatedAt'), findsOneWidget);
      expect(find.byIcon(Icons.event), findsOneWidget);
      expect(find.text('48.8584,2.2945'), findsOneWidget);
    });

    _testWidgets('opens the sdb databases and edits a record', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      await tester.tap(find.text('Sdb explorer'));
      await _settle(tester);
      expect(find.text('sdb_demo.db'), findsOneWidget);
      // Only the sdb one, the sembast database is left out.
      expect(find.text('sembast_demo.db'), findsNothing);

      await tester.tap(find.text('sdb_demo.db'));
      await _settle(tester);
      expect(find.text('note'), findsOneWidget);

      await tester.tap(find.text('note'));
      await _settle(tester);
      await tester.tap(find.text('first'));
      await _settle(tester);
      // Full edition: the record opens in the editor, save and all.
      expect(find.text('title'), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
    });

    _testWidgets('opens the sembast databases', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      await tester.tap(find.text('Sembast explorer'));
      await _settle(tester);
      expect(find.text('sembast_demo.db'), findsOneWidget);
      expect(find.text('sdb_demo.db'), findsNothing);

      await tester.tap(find.text('sembast_demo.db'));
      await _settle(tester);
      expect(find.text('settings'), findsOneWidget);
      expect(find.text('event'), findsOneWidget);
    });

    _testWidgets('opens the file system explorer, writable', (tester) async {
      await tester.pumpWidget(const FestenaoExplorersDemoApp());
      await _settle(tester);

      await tester.tap(find.text('File system explorer'));
      await _settle(tester);
      expect(find.text('config.json'), findsOneWidget);
      expect(find.text('picture.bin'), findsOneWidget);
      // Writable: the create button is there, no padlock.
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });
  });
}

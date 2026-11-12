import 'dart:convert';

import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:festenao_common_flutter/src/files_system_explorer_flutter.dart'
    show pickFileSystemDirectory;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:material_ui/material_ui.dart';

/// See the file system explorer tests: real timers, the file system is really
/// asynchronous.
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

/// A home with a button pushing an app page, the explorer pushed from it.
Widget _homeApp() => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('app page')),
            ),
          ),
          child: const Text('home'),
        ),
      ),
    ),
  ),
);

void main() {
  group('FileSystemHexFileScreen', () {
    _testWidgets('typing in the find bar never edits the bytes', (
      tester,
    ) async {
      var explorer = FileSystemExplorer(
        fileSystem: newFileSystemMemory(),
        rootPath: 'root',
      );
      await explorer.writeAsBytes('data.bin', utf8.encode('Hello'));
      await tester.pumpWidget(
        MaterialApp(
          home: FileSystemHexFileScreen(explorer: explorer, path: 'data.bin'),
        ),
      );
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.search));
      await _settle(tester);
      await tester.tap(find.text('Hex'));
      await _settle(tester);
      await tester.enterText(find.byKey(const ValueKey('explorerFind')), '6c');
      await _settle(tester);
      // The current match is selected in the dump...
      expect(find.textContaining('@ 0x2 (2)'), findsOneWidget);
      // ...while the focus stays in the find field.
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'find');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await _settle(tester);
      expect(find.textContaining('unsaved'), findsNothing);
      expect(find.textContaining('|Hello|'), findsOneWidget);
    });
  });

  group('FileSystemExplorerScreen breadcrumb', () {
    _testWidgets('opened on a sub path, never pops the app routes', (
      tester,
    ) async {
      var explorer = FileSystemExplorer(
        fileSystem: newFileSystemMemory(),
        rootPath: 'root',
      );
      await explorer.createDirectory('a/b/c');
      await tester.pumpWidget(_homeApp());
      await tester.tap(find.text('home'));
      await _settle(tester);
      var context = tester.element(find.text('app page'));
      // ignore: unawaited_futures
      goToFileSystemExplorerScreen(context, explorer: explorer, path: 'a/b');
      await _settle(tester);
      // Down one level, then the crumb of the first screen: back on it.
      await tester.tap(find.widgetWithText(ListTile, 'c'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(InkWell, 'b').last);
      await _settle(tester);
      expect(find.widgetWithText(ListTile, 'c'), findsOneWidget);
      // Above the first screen: the parent is shown on top of it.
      await tester.tap(find.widgetWithText(InkWell, 'root').last);
      await _settle(tester);
      expect(find.widgetWithText(ListTile, 'a'), findsOneWidget);
      // Back: the screen it was opened on, then the app page, still there.
      await tester.pageBack();
      await _settle(tester);
      expect(find.widgetWithText(ListTile, 'c'), findsOneWidget);
      await tester.pageBack();
      await _settle(tester);
      expect(find.text('app page'), findsOneWidget);
    });

    _testWidgets('opened at the root, goes up by popping', (tester) async {
      var explorer = FileSystemExplorer(
        fileSystem: newFileSystemMemory(),
        rootPath: 'root',
      );
      await explorer.createDirectory('a/b');
      await tester.pumpWidget(_homeApp());
      await tester.tap(find.text('home'));
      await _settle(tester);
      var context = tester.element(find.text('app page'));
      // ignore: unawaited_futures
      goToFileSystemExplorerScreen(context, explorer: explorer);
      await _settle(tester);
      await tester.tap(find.widgetWithText(ListTile, 'a'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(ListTile, 'b'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(InkWell, 'root').last);
      await _settle(tester);
      expect(find.widgetWithText(ListTile, 'a'), findsOneWidget);
      // One back and the app page shows: the root screen was not pushed
      // again.
      await tester.pageBack();
      await _settle(tester);
      expect(find.text('app page'), findsOneWidget);
    });

    _testWidgets('a picker opened on a sub path picks above it', (
      tester,
    ) async {
      var explorer = FileSystemExplorer(
        fileSystem: newFileSystemMemory(),
        rootPath: 'root',
      );
      await explorer.createDirectory('a/b');
      await tester.pumpWidget(_homeApp());
      await tester.tap(find.text('home'));
      await _settle(tester);
      var context = tester.element(find.text('app page'));
      String? picked;
      var done = false;
      // ignore: unawaited_futures
      pickFileSystemDirectory(context, explorer: explorer, path: 'a/b').then((
        value,
      ) {
        picked = value;
        done = true;
      });
      await _settle(tester);
      await tester.tap(find.widgetWithText(InkWell, 'a').last);
      await _settle(tester);
      await tester.tap(find.text('Select'));
      await _settle(tester);
      expect(done, isTrue);
      expect(picked, 'a');
      expect(find.text('app page'), findsOneWidget);
    });
  });

  group('festenaoFileSystemRoots', () {
    test('the Memory root keeps its files', () async {
      FileSystemRoot memoryRoot() =>
          festenaoFileSystemRoots(fileSystem: newFileSystemMemory())
              .singleWhere((root) => root.name == 'Memory');
      var directory = (await memoryRoot().resolve())!;
      await directory.fs
          .file(directory.fs.path.join(directory.path, 'kept.txt'))
          .writeAsString('kept');
      // Resolved again, by a picker opened again.
      var again = (await memoryRoot().resolve())!;
      expect(
        await again.fs
            .file(again.fs.path.join(again.path, 'kept.txt'))
            .readAsString(),
        'kept',
      );
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}

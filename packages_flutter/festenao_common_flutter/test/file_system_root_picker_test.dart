import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_shim/fs_memory.dart';

/// See the file system explorer tests: the file system is really
/// asynchronous, so everything runs with real timers.
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
  });
}

/// A file system holding one directory with one document in it.
Future<(FileSystem, Directory)> _newRoot() async {
  var fileSystem = newFileSystemMemory();
  await fileSystem.file('picked/config.json').create(recursive: true);
  await fileSystem.file('picked/config.json').writeAsString('{"name":"test"}');
  await fileSystem.file('outside.json').create(recursive: true);
  return (fileSystem, fileSystem.directory('picked'));
}

void main() {
  group('festenaoDirectoryExplorer', () {
    test('sandboxes the explorer in the directory', () async {
      var (_, directory) = await _newRoot();
      var explorer = festenaoDirectoryExplorer(directory);
      expect((await explorer.list()).single.name, 'config.json');
      // The sandbox is the whole world: nothing above it is reachable.
      expect(
        () => explorer.fsPath('../outside.json'),
        throwsA(isA<FileSystemExplorerPathException>()),
      );
    });

    test('makes a read only explorer', () async {
      var (_, directory) = await _newRoot();
      var explorer = festenaoDirectoryExplorer(directory, isReadOnly: true);
      expect(explorer.isReadOnly, isTrue);
      expect(explorer.delete('config.json'), throwsA(isA<ReadOnlyException>()));
    });
  });

  group('FileSystemRootPickerScreen', () {
    _testWidgets('lists the roots it can resolve and opens one', (
      tester,
    ) async {
      var (_, directory) = await _newRoot();
      await tester.pumpWidget(
        MaterialApp(
          home: FileSystemRootPickerScreen(
            roots: [
              FileSystemRoot(
                name: 'Picked',
                description: 'A memory directory',
                resolve: () async => directory,
              ),
              FileSystemRoot(name: 'Not here', resolve: () async => null),
            ],
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Picked'), findsOneWidget);
      // A root the platform has none of is left out.
      expect(find.text('Not here'), findsNothing);

      await tester.tap(find.text('Picked'));
      await _settle(tester);
      // The explorer, on that directory.
      expect(find.text('config.json'), findsOneWidget);
    });

    _testWidgets('opens read only when the toggle says so', (tester) async {
      var (_, directory) = await _newRoot();
      await tester.pumpWidget(
        MaterialApp(
          home: FileSystemRootPickerScreen(
            roots: [
              FileSystemRoot(name: 'Picked', resolve: () async => directory),
            ],
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Read write'), findsOneWidget);
      await tester.tap(find.text('Read write'));
      await _settle(tester);
      expect(find.text('Read only'), findsOneWidget);

      await tester.tap(find.text('Picked'));
      await _settle(tester);
      // The explorer it opened is a viewer: no way to create anything.
      expect(find.byIcon(Icons.add), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });
}

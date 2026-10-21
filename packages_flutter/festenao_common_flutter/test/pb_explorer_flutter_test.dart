import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:festenao_common_flutter/pb_explorer_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_app_pb/pb.dart';

/// See the file system explorer tests: real timers, since the file system is
/// really asynchronous.
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

/// Like an android `test-result.pb`: a status (2) and a test result (3), its
/// test case (1: class, 3: method) and its status (2).
List<int> _sampleBytes() => pbEncodeMessage(
  PbMessage()
    ..addInt(2, 3)
    ..addMessage(
      3,
      PbMessage()
        ..addMessage(
          1,
          PbMessage()
            ..addString(1, 'LocaleUtilsTest')
            ..addString(3, 'localeForLanguageTag'),
        )
        ..addInt(2, 3),
    )
    ..addString(4, 'done'),
);

Future<FileSystemExplorer> _newExplorer({
  bool isReadOnly = false,
  List<int>? bytes,
}) async {
  var fileSystem = newFileSystemMemory();
  await fileSystem.directory('root').create(recursive: true);
  var explorer = FileSystemExplorer(fileSystem: fileSystem, rootPath: 'root');
  await explorer.writeAsBytes('result.pb', bytes ?? _sampleBytes());
  await explorer.writeAsBytes('result.bin', _sampleBytes());
  return isReadOnly ? explorer.readOnly : explorer;
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FileSystemExplorer explorer, {
  String path = 'result.pb',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PbFileScreen(explorer: explorer, path: path),
    ),
  );
  await _settle(tester);
}

/// Opens the row menu of field [number] showing [preview].
Future<void> _openFieldMenu(WidgetTester tester, String preview) async {
  var row = find.ancestor(
    of: find.text(preview),
    matching: find.byType(InkWell),
  );
  await tester.tap(
    find.descendant(of: row.first, matching: find.byIcon(Icons.more_vert)),
  );
  await _settle(tester);
}

void main() {
  group('pbFileSystemOpener', () {
    _testWidgets('opens .pb files in the protobuf screen', (tester) async {
      var explorer = await _newExplorer();
      await tester.pumpWidget(
        MaterialApp(
          home: FileSystemExplorerScreen(
            explorer: explorer,
            fileOpeners: const [pbFileSystemOpener],
          ),
        ),
      );
      await _settle(tester);

      // Listed with the badge and the icon of the opener.
      expect(find.text('protobuf'), findsOneWidget);
      expect(find.byIcon(Icons.account_tree_outlined), findsOneWidget);

      await tester.tap(find.text('result.pb'));
      await _settle(tester);
      expect(find.byType(PbFileScreen), findsOneWidget);
      expect(find.text('"done"'), findsOneWidget);
    });

    _testWidgets('is offered by "open as…" for any file', (tester) async {
      var explorer = await _newExplorer();
      await tester.pumpWidget(
        MaterialApp(
          home: FileSystemExplorerScreen(
            explorer: explorer,
            fileOpeners: const [pbFileSystemOpener],
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'result.bin'),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Open as…'));
      await _settle(tester);
      await tester.tap(find.text('Protobuf'));
      await _settle(tester);
      expect(find.byType(PbFileScreen), findsOneWidget);
      expect(find.text('"done"'), findsOneWidget);
    });

    _testWidgets('without it, a .pb file is binary', (tester) async {
      var explorer = await _newExplorer();
      await tester.pumpWidget(
        MaterialApp(home: FileSystemExplorerScreen(explorer: explorer)),
      );
      await _settle(tester);

      expect(find.text('protobuf'), findsNothing);
      await tester.tap(find.text('result.pb'));
      await _settle(tester);
      expect(find.byType(FileSystemHexFileScreen), findsOneWidget);
    });

    test('matches the protobuf extensions', () {
      FileSystemEntry entry(String path) =>
          FileSystemEntry(path: path, kind: fileSystemEntryKindOf(path));
      expect(pbFileSystemOpener.matches(entry('a/b.pb')), isTrue);
      expect(pbFileSystemOpener.matches(entry('B.PB')), isTrue);
      expect(pbFileSystemOpener.matches(entry('c.binpb')), isTrue);
      expect(pbFileSystemOpener.matches(entry('c.bin')), isFalse);
      expect(pbFileSystemOpener.matches(entry('pb')), isFalse);
      expect(
        pbFileSystemOpener.matches(
          FileSystemEntry(path: 'd.pb', kind: FileSystemEntryKind.directory),
        ),
        isFalse,
      );
      expect(
        fileSystemFileOpenerOf([pbFileSystemOpener], entry('x.pb')),
        pbFileSystemOpener,
      );
      expect(
        fileSystemFileOpenerOf([pbFileSystemOpener], entry('x.txt')),
        isNull,
      );
    });
  });

  group('PbFileScreen', () {
    _testWidgets('lists the fields and expands the messages', (tester) async {
      var explorer = await _newExplorer();
      await _pumpScreen(tester, explorer);

      expect(find.text('2 fields'), findsOneWidget);
      expect(find.text('"done"'), findsOneWidget);
      expect(find.textContaining('3 top fields'), findsOneWidget);
      expect(find.text('"LocaleUtilsTest"'), findsNothing);

      await tester.tap(find.text('2 fields'));
      await _settle(tester);
      await tester.tap(find.text('2 fields').last);
      await _settle(tester);
      expect(find.text('"LocaleUtilsTest"'), findsOneWidget);
      expect(find.text('"localeForLanguageTag"'), findsOneWidget);
    });

    _testWidgets('shows the file as text', (tester) async {
      var explorer = await _newExplorer();
      await _pumpScreen(tester, explorer);

      await tester.tap(find.byTooltip('Show as text'));
      await _settle(tester);
      // A line a row, in the monospace font.
      expect(find.text('3 {'), findsOneWidget);
      expect(find.text('    1: "LocaleUtilsTest"'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('3 {')).style?.fontFamilyFallback,
        contains('monospace'),
      );
    });

    _testWidgets('finds in the text view', (tester) async {
      var explorer = await _newExplorer();
      await _pumpScreen(tester, explorer);

      // Ctrl+F shows the text view and the find bar.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _settle(tester);
      expect(find.text('3 {'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('explorerFind')),
        ' LOCALE ',
      );
      await _settle(tester);
      // Any: trimmed, case ignored; in the class and the method.
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);
      expect(find.text('2 / 2'), findsOneWidget);

      await tester.tap(find.text('Exact'));
      await _settle(tester);
      expect(find.text('No match'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('explorerFind')),
        'Locale',
      );
      await _settle(tester);
      expect(find.text('1 / 1'), findsOneWidget);

      await tester.tap(find.byTooltip('Close (escape)'));
      await _settle(tester);
      expect(find.byKey(const ValueKey('explorerFind')), findsNothing);
    });

    _testWidgets('shows the details of a value', (tester) async {
      var explorer = await _newExplorer();
      await _pumpScreen(tester, explorer);

      // The first field, a varint 3.
      await tester.tap(find.text('3').first);
      await _settle(tester);
      expect(find.text('Field 2'), findsOneWidget);
      expect(find.text('uint64'), findsOneWidget);
      expect(find.text('sint64'), findsOneWidget);
      expect(find.text('-2'), findsOneWidget);
    });

    _testWidgets('edits a string and saves the file', (tester) async {
      var explorer = await _newExplorer();
      await _pumpScreen(tester, explorer);

      await _openFieldMenu(tester, '"done"');
      await tester.tap(find.text('Edit…'));
      await _settle(tester);
      await tester.enterText(find.byKey(const ValueKey('pbValue')), 'passed');
      await tester.tap(find.text('Ok'));
      await _settle(tester);
      expect(find.text('"passed"'), findsOneWidget);
      expect(find.text('unsaved'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.save));
      await _settle(tester);
      var message = pbDecodeMessage(await explorer.readAsBytes('result.pb'));
      expect(message.stringValue(4), 'passed');
      // The rest is untouched.
      expect(
        message.messageValue(3)!.messageValue(1)!.stringValue(1),
        'LocaleUtilsTest',
      );
    });

    _testWidgets('refuses a value that does not parse', (tester) async {
      var explorer = await _newExplorer();
      await _pumpScreen(tester, explorer);

      await tester.tap(find.text('3').first);
      await _settle(tester);
      await tester.tap(find.text('Edit'));
      await _settle(tester);
      await tester.enterText(find.byKey(const ValueKey('pbValue')), 'many');
      await tester.tap(find.text('Ok'));
      await _settle(tester);
      expect(find.textContaining('not an integer'), findsOneWidget);
    });

    _testWidgets('adds and deletes fields', (tester) async {
      var explorer = await _newExplorer();
      await _pumpScreen(tester, explorer);

      await tester.tap(find.byTooltip('Add a top field'));
      await _settle(tester);
      // The next free number is suggested.
      expect(find.text('5'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('pbValue')), 'extra');
      await tester.tap(find.text('Ok'));
      await _settle(tester);
      expect(find.text('"extra"'), findsOneWidget);

      await _openFieldMenu(tester, '"done"');
      await tester.tap(find.text('Delete'));
      await _settle(tester);
      await tester.tap(find.text('Delete').last);
      await _settle(tester);
      expect(find.text('"done"'), findsNothing);

      await tester.tap(find.byIcon(Icons.save));
      await _settle(tester);
      var message = pbDecodeMessage(await explorer.readAsBytes('result.pb'));
      expect(message.numbers, [2, 3, 5]);
      expect(message.stringValue(5), 'extra');
    });

    _testWidgets('views a value another way', (tester) async {
      var explorer = await _newExplorer();
      await _pumpScreen(tester, explorer);

      await _openFieldMenu(tester, '"done"');
      await tester.tap(find.text('View as…'));
      await _settle(tester);
      await tester.tap(find.text('bytes'));
      await _settle(tester);
      expect(find.text('4 bytes  64 6f 6e 65'), findsOneWidget);
    });

    _testWidgets('says when a file is not protobuf', (tester) async {
      var explorer = await _newExplorer(bytes: [0x0f, 0x01]);
      await _pumpScreen(tester, explorer);

      expect(find.text('Not a protobuf message'), findsOneWidget);
      expect(find.text('invalid'), findsOneWidget);
      await tester.tap(find.text('Open in the hex editor'));
      await _settle(tester);
      expect(find.byType(FileSystemHexFileScreen), findsOneWidget);
    });

    _testWidgets('a read only explorer only views', (tester) async {
      var explorer = await _newExplorer(isReadOnly: true);
      await _pumpScreen(tester, explorer);

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.save), findsNothing);
      expect(find.byTooltip('Add a top field'), findsNothing);
      await _openFieldMenu(tester, '"done"');
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Edit…'), findsNothing);
      expect(find.text('Delete'), findsNothing);
    });
  });
}

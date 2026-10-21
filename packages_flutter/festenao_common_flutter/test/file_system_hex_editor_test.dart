import 'dart:convert';

import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:festenao_theme/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:material_ui/material_ui.dart';

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

Future<FileSystemExplorer> _newExplorer(
  List<int> bytes, {
  bool isReadOnly = false,
}) async {
  var fileSystem = newFileSystemMemory();
  await fileSystem.file('root/data.bin').create(recursive: true);
  var explorer = FileSystemExplorer(fileSystem: fileSystem, rootPath: 'root');
  await explorer.writeAsBytes('data.bin', bytes);
  return isReadOnly ? explorer.readOnly : explorer;
}

Future<void> _pump(WidgetTester tester, FileSystemExplorer explorer) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FileSystemHexFileScreen(explorer: explorer, path: 'data.bin'),
    ),
  );
  await _settle(tester);
}

/// The width of a character of the dump.
double _charWidth() {
  var painter = TextPainter(
    text: const TextSpan(
      text: '0123456789',
      style: TextStyle(fontFamily: festenaoMonospaceFontFamily, fontSize: 13),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  var width = painter.width / 10;
  painter.dispose();
  return width;
}

/// Taps the character [position] of the row showing [rowText].
Future<void> _tapChar(WidgetTester tester, String rowText, int position) async {
  var row = find.textContaining(rowText);
  var topLeft = tester.getTopLeft(row);
  var width = _charWidth();
  await tester.tapAt(topLeft + Offset((position + 0.5) * width, 6));
  await _settle(tester);
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

void main() {
  group('hex formatting', () {
    test('prints the offset, the bytes and the text column', () {
      expect(fileSystemHexOffset(0), '00000000');
      expect(fileSystemHexOffset(255), '000000ff');
      expect(
        fileSystemHexBytes([0x48, 0x69]),
        // Padded to the row width, so the columns line up on the last row.
        '48 69                                          ',
      );
      expect(fileSystemHexBytes([0x48, 0x69], bytesPerRow: 4), '48 69      ');
      expect(fileSystemHexText([0x48, 0x69, 0x00, 0xff]), 'Hi..');
      expect(fileSystemHexChar(0x41), 'A');
      expect(fileSystemHexChar(0x7f), '.');
    });

    test('reads hex back, with or without spaces', () {
      expect(fileSystemHexParse('48 69'), [0x48, 0x69]);
      expect(fileSystemHexParse('4869'), [0x48, 0x69]);
      expect(fileSystemHexParse(''), isEmpty);
      expect(fileSystemHexParse('48 6'), isNull);
      expect(fileSystemHexParse('zz'), isNull);
    });
  });

  group('FileSystemHexLayout', () {
    test('places the columns', () {
      var layout = const FileSystemHexLayout(16);
      // 00000000  48 65 6c 6c 6f 00 ff 00  01 02 03 04 05 06 07 08  |Hello...........|
      expect(layout.hexStart(0), 10);
      expect(layout.hexStart(7), 31);
      expect(layout.hexStart(8), 35);
      expect(layout.hexChars, 48);
      expect(layout.textStart, 61);
      expect(layout.rowChars, 78);
    });

    test('fits the widest row in the width', () {
      expect(FileSystemHexLayout.auto(0).bytesPerRow, 4);
      expect(FileSystemHexLayout.auto(77).bytesPerRow, 8);
      expect(FileSystemHexLayout.auto(78).bytesPerRow, 16);
      expect(
        FileSystemHexLayout.auto(const FileSystemHexLayout(32).rowChars)
            .bytesPerRow,
        32,
      );
      expect(FileSystemHexLayout.auto(10000).bytesPerRow, 64);
    });

    test('hit tests a character to a byte and a column', () {
      var layout = const FileSystemHexLayout(16);
      expect(layout.hitTest(0), isNull);
      expect(layout.hitTest(9), isNull);
      expect(layout.hitTest(10), (
        index: 0,
        column: FileSystemHexColumn.hex,
        nibble: 0,
      ));
      expect(layout.hitTest(11), (
        index: 0,
        column: FileSystemHexColumn.hex,
        nibble: 1,
      ));
      // The space after a pair goes with it.
      expect(layout.hitTest(12)!.index, 0);
      expect(layout.hitTest(13)!.index, 1);
      expect(layout.hitTest(35)!.index, 8);
      expect(layout.hitTest(57)!.index, 15);
      expect(layout.hitTest(58), isNull);
      expect(layout.hitTest(60), isNull);
      expect(layout.hitTest(61), (
        index: 0,
        column: FileSystemHexColumn.text,
        nibble: 0,
      ));
      expect(layout.hitTest(76)!.index, 15);
      expect(layout.hitTest(77), isNull);
    });
  });

  group('FileSystemHexFileScreen', () {
    _testWidgets('dumps the bytes with their text column', (tester) async {
      var explorer = await _newExplorer([...utf8.encode('Hello'), 0x00, 0xff]);
      await _pump(tester, explorer);

      expect(find.textContaining('00000000'), findsOneWidget);
      expect(find.textContaining('48 65 6c 6c 6f 00 ff'), findsOneWidget);
      expect(find.textContaining('|Hello..|'), findsOneWidget);
      expect(find.text('7 bytes'), findsOneWidget);
    });

    _testWidgets('fits the bytes per row to the width', (tester) async {
      var explorer = await _newExplorer(List.generate(64, (index) => index));
      var charWidth = _charWidth();
      // Wide enough for 32 bytes a row, not 48.
      tester.view.physicalSize = Size(
        const FileSystemHexLayout(32).rowChars * charWidth + 40,
        800,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(tester, explorer);
      expect(find.textContaining('rows of 32'), findsOneWidget);
      expect(find.textContaining('00000020'), findsOneWidget);
      expect(find.textContaining('00000010'), findsNothing);

      // Picking a width overrides the fit.
      await tester.tap(find.byIcon(Icons.view_column_outlined));
      await _settle(tester);
      await tester.tap(find.text('16 bytes per row'));
      await _settle(tester);
      expect(find.textContaining('rows of 16'), findsOneWidget);
      expect(find.textContaining('00000010'), findsOneWidget);
    });

    _testWidgets('previews the text when the bytes are utf8', (tester) async {
      var explorer = await _newExplorer(utf8.encode('Readable text'));
      await _pump(tester, explorer);

      expect(find.text('Text preview (utf8)'), findsOneWidget);
      expect(find.text('Readable text'), findsOneWidget);
    });

    _testWidgets('has no preview when the bytes are not utf8', (tester) async {
      var explorer = await _newExplorer([0xff, 0xfe, 0xfd]);
      await _pump(tester, explorer);

      expect(find.text('Text preview (utf8)'), findsNothing);
      expect(find.textContaining('ff fe fd'), findsOneWidget);
    });

    _testWidgets('types hex and text in the selected byte', (tester) async {
      var explorer = await _newExplorer(utf8.encode('Hello'));
      await _pump(tester, explorer);
      var layout = const FileSystemHexLayout(8);

      // The high digit of the first byte, in the hex column.
      await _tapChar(tester, '48 65', layout.hexStart(0));
      expect(find.textContaining('@ 0x0 (0)'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.digit4);
      await _key(tester, LogicalKeyboardKey.keyA);
      await _settle(tester);
      expect(find.textContaining('|Jello|'), findsOneWidget);
      // The selection moved on to the next byte.
      expect(find.textContaining('@ 0x1 (1)'), findsOneWidget);

      // The last byte, in the text column.
      await _tapChar(tester, '4a 65', layout.textStart + 4);
      expect(find.textContaining('@ 0x4 (4)'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.keyY);
      await _settle(tester);
      // The selection is now the end, where typing appends.
      expect(find.textContaining('|Jelly_|'), findsOneWidget);
      expect(find.textContaining('end of file'), findsOneWidget);

      // Typing on at the end appends.
      await _key(tester, LogicalKeyboardKey.keyS);
      await _settle(tester);
      expect(find.textContaining('|Jellys_|'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await _settle(tester);
      expect(await explorer.readAsBytes('data.bin'), utf8.encode('Jellys'));
    });

    _testWidgets('moves, deletes and inserts with the keys', (tester) async {
      var explorer = await _newExplorer(utf8.encode('Hello'));
      await _pump(tester, explorer);
      var layout = const FileSystemHexLayout(8);

      await _tapChar(tester, '48 65', layout.hexStart(0));
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(find.textContaining('@ 0x1 (1)'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.delete);
      await _settle(tester);
      expect(find.textContaining('|Hllo|'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.backspace);
      await _settle(tester);
      expect(find.textContaining('|llo|'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.insert);
      await _settle(tester);
      expect(find.textContaining('00 6c 6c 6f'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(find.textContaining('@ 0x'), findsNothing);
    });

    _testWidgets('writes and inserts from the selection bar', (tester) async {
      var explorer = await _newExplorer(utf8.encode('Hello'));
      await _pump(tester, explorer);
      var layout = const FileSystemHexLayout(8);

      await _tapChar(tester, '48 65', layout.textStart + 1);
      await tester.tap(find.byTooltip('Write bytes here'));
      await _settle(tester);
      await tester.tap(find.text('Text'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'ipp');
      await tester.tap(find.text('Ok'));
      await _settle(tester);
      expect(find.textContaining('|Hippo|'), findsOneWidget);

      await tester.tap(find.byTooltip('Insert bytes here (Insert)'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), '2d 2d');
      await tester.tap(find.text('Ok'));
      await _settle(tester);
      expect(find.textContaining('|Hipp--o|'), findsOneWidget);
    });

    _testWidgets('retypes a row and saves it', (tester) async {
      var explorer = await _newExplorer(utf8.encode('Hello'));
      await _pump(tester, explorer);

      await _tapChar(tester, '48 65', const FileSystemHexLayout(8).hexStart(2));
      await tester.tap(find.byTooltip('Retype the row'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), '4a 65 6c 6c 6f');
      await tester.tap(find.text('Ok'));
      await _settle(tester);

      expect(find.textContaining('|Jello|'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.save));
      await _settle(tester);

      expect(await explorer.readAsBytes('data.bin'), utf8.encode('Jello'));
    });

    _testWidgets('refuses bytes that are not hex', (tester) async {
      var explorer = await _newExplorer(utf8.encode('Hi'));
      await _pump(tester, explorer);

      await tester.tap(find.byIcon(Icons.add));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'not hex');
      await tester.tap(find.text('Ok'));
      await _settle(tester);

      expect(find.text('Not a run of hex bytes'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(await explorer.readAsBytes('data.bin'), utf8.encode('Hi'));
    });

    _testWidgets('appends bytes at the end', (tester) async {
      var explorer = await _newExplorer(utf8.encode('Hi'));
      await _pump(tester, explorer);

      await tester.tap(find.byIcon(Icons.add));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), '21');
      await tester.tap(find.text('Ok'));
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.save));
      await _settle(tester);

      expect(await explorer.readAsBytes('data.bin'), utf8.encode('Hi!'));
    });

    _testWidgets('a read only explorer neither edits nor saves', (
      tester,
    ) async {
      var explorer = await _newExplorer(utf8.encode('Hello'), isReadOnly: true);
      await _pump(tester, explorer);

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.save), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
      // The rows are there to read and select, not to edit.
      expect(find.textContaining('|Hello|'), findsOneWidget);
      await _tapChar(tester, '48 65', const FileSystemHexLayout(8).hexStart(0));
      expect(find.textContaining('@ 0x0 (0)'), findsOneWidget);
      expect(find.byTooltip('Write bytes here'), findsNothing);
      expect(find.byTooltip('Retype the row'), findsNothing);
      await _key(tester, LogicalKeyboardKey.digit4);
      await _settle(tester);
      expect(find.textContaining('|Hello|'), findsOneWidget);
    });
  });
}

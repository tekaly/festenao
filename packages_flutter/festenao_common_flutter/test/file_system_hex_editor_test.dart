import 'dart:convert';

import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_shim/fs_memory.dart';

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
      expect(fileSystemHexText([0x48, 0x69, 0x00, 0xff]), 'Hi..');
    });

    test('reads hex back, with or without spaces', () {
      expect(fileSystemHexParse('48 69'), [0x48, 0x69]);
      expect(fileSystemHexParse('4869'), [0x48, 0x69]);
      expect(fileSystemHexParse(''), isEmpty);
      expect(fileSystemHexParse('48 6'), isNull);
      expect(fileSystemHexParse('zz'), isNull);
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

    _testWidgets('edits a row and saves it', (tester) async {
      var explorer = await _newExplorer(utf8.encode('Hello'));
      await _pump(tester, explorer);

      await tester.tap(find.textContaining('48 65 6c 6c 6f'));
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

      await tester.tap(find.textContaining('48 69'));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'not hex');
      await tester.tap(find.text('Ok'));
      await _settle(tester);

      expect(find.text('Not a run of hex bytes'), findsOneWidget);
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
      // The rows are there to read, they just do not open an editor.
      expect(find.textContaining('|Hello|'), findsOneWidget);
      await tester.tap(find.textContaining('48 65 6c 6c 6f'));
      await _settle(tester);
      expect(find.text('Ok'), findsNothing);
    });
  });
}

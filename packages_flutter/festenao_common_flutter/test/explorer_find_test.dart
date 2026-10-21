import 'dart:convert';

import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
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

List<String> _found(String text, String query, ExplorerFindMode mode) => [
  for (var range in ExplorerTextFinder(text).find(query, mode))
    range.textInside(text),
];

Future<void> _ctrlF(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await _settle(tester);
}

final _findField = find.byKey(const ValueKey('explorerFind'));

void main() {
  group('find in text', () {
    test('any ignores case and accents, and trims the query', () {
      expect(explorerAnyQuery('  Élève '), 'eleve');
      var text = 'Un élève, une ELEVE, des eleves.';
      expect(_found(text, ' Élève ', ExplorerFindMode.any), [
        'élève',
        'ELEVE',
        'eleve',
      ]);
      expect(_found(text, 'élève', ExplorerFindMode.exact), ['élève']);
      expect(_found(text, 'Eleve', ExplorerFindMode.exact), isEmpty);
      expect(_found(text, '   ', ExplorerFindMode.any), isEmpty);
      expect(_found(text, '', ExplorerFindMode.exact), isEmpty);
      expect(_found(text, 'eleve', ExplorerFindMode.hex), isEmpty);
    });

    test('maps the matches back when the length changes', () {
      // A combining accent goes, Æ becomes AE.
      var text = 'Café Æsop';
      expect(_found(text, 'cafe', ExplorerFindMode.any), ['Café']);
      expect(_found(text, 'aesop', ExplorerFindMode.any), ['Æsop']);
      expect(_found(text, 'e', ExplorerFindMode.any), ['é', 'Æ']);
      expect(_found(text, 'a', ExplorerFindMode.any), ['a', 'Æ']);
      var any = ExplorerAnyText(text);
      expect(any.normalized, 'cafe aesop');
    });

    test('finds without overlapping, at most max', () {
      expect(_found('aaaa', 'aa', ExplorerFindMode.exact), ['aa', 'aa']);
      expect(
        ExplorerTextFinder('a' * 50).find('a', ExplorerFindMode.any, max: 10),
        hasLength(10),
      );
    });
  });

  group('find in bytes', () {
    List<int> found(List<int> bytes, String query, ExplorerFindMode mode) => [
      for (var range in ExplorerBytesFinder(bytes).find(query, mode))
        range.start,
    ];

    test('reads utf8, latin1 otherwise', () {
      var decoded = explorerBytesAsText([
        ...utf8.encode('Café 😀'),
        0xe9,
        0xff,
      ]);
      expect(decoded.text, 'Café 😀éÿ');
      // é takes 2 bytes, the emoji 4 (2 code units), the latin1 ones 1.
      expect(decoded.byteOffsets, [0, 1, 2, 3, 5, 6, 6, 10, 11, 12]);
    });

    test('text modes, as byte ranges', () {
      var bytes = [0x00, ...utf8.encode('Un Élève'), 0x01, 0xe9, 0x6c];
      var finder = ExplorerBytesFinder(bytes);
      var any = finder.find('eleve', ExplorerFindMode.any);
      // É and è take 2 bytes each.
      expect(any, [const TextRange(start: 4, end: 11)]);
      // The latin1 é too.
      expect(found(bytes, 'el', ExplorerFindMode.any), [4, 12]);
      expect(found(bytes, 'Élève', ExplorerFindMode.exact), [4]);
      expect(found(bytes, 'élève', ExplorerFindMode.exact), isEmpty);
    });

    test('hex mode', () {
      var bytes = [0x01, 0x02, 0x03, 0x01, 0x02];
      expect(found(bytes, '01 02', ExplorerFindMode.hex), [0, 3]);
      expect(found(bytes, '0102', ExplorerFindMode.hex), [0, 3]);
      expect(found(bytes, '02 04', ExplorerFindMode.hex), isEmpty);
      expect(found(bytes, 'xyz', ExplorerFindMode.hex), isEmpty);
      expect(found(bytes, '', ExplorerFindMode.hex), isEmpty);
    });
  });

  test('explorerFirstRangeEndingAfter', () {
    var ranges = const [
      TextRange(start: 0, end: 2),
      TextRange(start: 5, end: 8),
      TextRange(start: 10, end: 11),
    ];
    expect(explorerFirstRangeEndingAfter(ranges, 0), 0);
    expect(explorerFirstRangeEndingAfter(ranges, 2), 1);
    expect(explorerFirstRangeEndingAfter(ranges, 7), 1);
    expect(explorerFirstRangeEndingAfter(ranges, 8), 2);
    expect(explorerFirstRangeEndingAfter(ranges, 11), 3);
  });

  test('ExplorerFindController', () {
    var text = 'one two one two one';
    var controller = ExplorerFindController(
      search: (query, mode) => ExplorerTextFinder(text).find(query, mode),
    );
    addTearDown(controller.dispose);
    expect(controller.isOpen, isFalse);
    controller.open();
    expect(controller.counter, '');
    controller.textController.text = 'ONE';
    controller.queryChanged();
    expect(controller.matches, hasLength(3));
    expect(controller.counter, '1 / 3');
    var reveals = controller.revealCount;
    controller.next();
    expect(controller.currentMatch, const TextRange(start: 8, end: 11));
    expect(controller.revealCount, reveals + 1);
    controller.previous();
    controller.previous();
    expect(controller.counter, '3 / 3');
    // Found again after an edit: the view does not move.
    reveals = controller.revealCount;
    controller.refresh();
    expect(controller.revealCount, reveals);
    expect(controller.counter, '3 / 3');
    controller.setMode(ExplorerFindMode.exact);
    expect(controller.counter, 'No match');
    controller.setMode(ExplorerFindMode.hex);
    expect(controller.counter, 'Not hex');
    controller.close();
    expect(controller.matches, isEmpty);
    expect(controller.query, 'ONE');
  });

  group('FileSystemTextFileScreen', () {
    Future<FileSystemExplorer> newExplorer({bool isReadOnly = false}) async {
      var fileSystem = newFileSystemMemory();
      await fileSystem.directory('root').create(recursive: true);
      var explorer = FileSystemExplorer(
        fileSystem: fileSystem,
        rootPath: 'root',
      );
      await explorer.writeAsString(
        'notes.txt',
        'Hello world\nÉtude du Monde\nend',
      );
      return isReadOnly ? explorer.readOnly : explorer;
    }

    _testWidgets('finds in the text, monospace', (tester) async {
      var explorer = await newExplorer();
      await tester.pumpWidget(
        MaterialApp(
          home: FileSystemTextFileScreen(explorer: explorer, path: 'notes.txt'),
        ),
      );
      await _settle(tester);
      var editor = tester.widget<TextField>(find.byType(TextField));
      expect(editor.style?.fontFamilyFallback, contains('monospace'));

      await tester.tap(find.byTooltip('Find (Ctrl+F)'));
      await _settle(tester);
      await tester.enterText(_findField, 'monde ');
      await _settle(tester);
      // "world" no, "Monde" yes: case ignored, trimmed.
      expect(find.text('1 / 1'), findsOneWidget);
      await tester.enterText(_findField, 'etu');
      await _settle(tester);
      expect(find.text('1 / 1'), findsOneWidget);
      await tester.tap(find.text('Exact'));
      await _settle(tester);
      expect(find.text('No match'), findsOneWidget);
      await tester.tap(find.text('Any'));
      await _settle(tester);

      // Closing goes back to the text, the match selected.
      await tester.tap(find.byTooltip('Close (escape)'));
      await _settle(tester);
      var controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      expect(controller.selection.textInside(controller.text), 'Étu');
    });

    _testWidgets('finds in a read only text too', (tester) async {
      var explorer = await newExplorer(isReadOnly: true);
      await tester.pumpWidget(
        MaterialApp(
          home: FileSystemTextFileScreen(explorer: explorer, path: 'notes.txt'),
        ),
      );
      await _settle(tester);
      await _ctrlF(tester);
      await tester.enterText(_findField, 'o');
      await _settle(tester);
      // Hello, world, Monde.
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);
      expect(find.text('2 / 3'), findsOneWidget);
    });
  });

  group('FileSystemHexFileScreen', () {
    _testWidgets('finds text and hex, selecting the match', (tester) async {
      var fileSystem = newFileSystemMemory();
      await fileSystem.directory('root').create(recursive: true);
      var explorer = FileSystemExplorer(
        fileSystem: fileSystem,
        rootPath: 'root',
      );
      await explorer.writeAsBytes('data.bin', [
        0x00,
        ...utf8.encode('Hello Élève'),
        0xff,
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: FileSystemHexFileScreen(explorer: explorer, path: 'data.bin'),
        ),
      );
      await _settle(tester);

      await _ctrlF(tester);
      await tester.enterText(_findField, 'ELEVE');
      await _settle(tester);
      expect(find.text('1 / 1'), findsOneWidget);
      // Selected at the match, in the text column.
      expect(find.textContaining('@ 0x7 (7)'), findsOneWidget);

      await tester.tap(find.text('Hex'));
      await _settle(tester);
      await tester.enterText(_findField, 'ff');
      await _settle(tester);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.textContaining('@ 0xe (14)'), findsOneWidget);
      await tester.enterText(_findField, 'zz');
      await _settle(tester);
      expect(find.text('Not hex'), findsOneWidget);
    });
  });

  group('FileSystemDirectoryAction', () {
    _testWidgets('is in the app bar, all the way down', (tester) async {
      var fileSystem = newFileSystemMemory();
      await fileSystem.directory('root/sub').create(recursive: true);
      var explorer = FileSystemExplorer(
        fileSystem: fileSystem,
        rootPath: 'root',
      );
      var pressed = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: FileSystemExplorerScreen(
            explorer: explorer,
            directoryActions: [
              FileSystemDirectoryAction(
                label: 'My view',
                icon: Icons.photo_library_outlined,
                onPressed: (context, explorer, path) => pressed.add(path),
              ),
            ],
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.byTooltip('My view'));
      await tester.tap(find.text('sub'));
      await _settle(tester);
      await tester.tap(find.byTooltip('My view'));
      expect(pressed, ['', 'sub']);
    });
  });
}

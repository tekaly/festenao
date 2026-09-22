import 'package:festenao_common_flutter/object_editor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The clipboard of the system, faked: the platform channel answers nothing in
/// a test, so this stands in for it and lets both directions be checked.
class _FakeSystemClipboard {
  String? text;

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            text = (call.arguments as Map)['text'] as String?;
            return null;
          case 'Clipboard.getData':
            return text == null ? null : <String, Object?>{'text': text};
        }
        return null;
      },
    );
  }

  void remove(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  }
}

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// Opens the row menu of the field named [name].
Future<void> _openMenu(WidgetTester tester, String name) async {
  await tester.tap(
    find.descendant(
      of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
      matching: find.byIcon(Icons.more_vert),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late _FakeSystemClipboard system;
  late FlutterObjectClipboard clipboard;

  setUp(() {
    system = _FakeSystemClipboard();
    clipboard = FlutterObjectClipboard(clipboard: ObjectClipboard());
  });

  group('copy and paste', () {
    testWidgets('copies a field and pastes it as another', (tester) async {
      system.install(tester);
      var editor = ObjectEditor({
        'source': {'nested': 1},
        'target': <String, Object?>{},
      });
      await tester.pumpWidget(
        _app(ObjectEditorView(editor: editor, clipboard: clipboard)),
      );

      await _openMenu(tester, 'source');
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(clipboard.isNotEmpty, isTrue);
      // It went to the clipboard of the system too, as json.
      expect(system.text, contains('"nested": 1'));

      await _openMenu(tester, 'target');
      await tester.tap(find.text('Paste as a field'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'copied');
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();

      expect(editor.value, {
        'source': {'nested': 1},
        'target': {
          'copied': {'nested': 1},
        },
      });
      system.remove(tester);
    });

    testWidgets('pastes over a value', (tester) async {
      system.install(tester);
      var editor = ObjectEditor({'a': 'first', 'b': 'second'});
      await tester.pumpWidget(
        _app(ObjectEditorView(editor: editor, clipboard: clipboard)),
      );

      await _openMenu(tester, 'a');
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      await _openMenu(tester, 'b');
      await tester.tap(find.text('Paste here'));
      await tester.pumpAndSettle();

      expect(editor.value, {'a': 'first', 'b': 'first'});
      system.remove(tester);
    });

    testWidgets('pastes an item into a list', (tester) async {
      system.install(tester);
      var editor = ObjectEditor({'value': 'x', 'items': <Object?>[]});
      await tester.pumpWidget(
        _app(ObjectEditorView(editor: editor, clipboard: clipboard)),
      );

      await _openMenu(tester, 'value');
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      await _openMenu(tester, 'items');
      await tester.tap(find.text('Paste as an item'));
      await tester.pumpAndSettle();

      expect(editor.value, {
        'value': 'x',
        'items': ['x'],
      });
      system.remove(tester);
    });

    testWidgets('takes what another app put on the clipboard', (tester) async {
      system.install(tester);
      system.text = '{"from": "elsewhere"}';
      var editor = ObjectEditor({'a': 1});
      await tester.pumpWidget(
        _app(ObjectEditorView(editor: editor, clipboard: clipboard)),
      );

      await _openMenu(tester, '/');
      await tester.tap(find.text('Paste here'));
      await tester.pumpAndSettle();

      expect(editor.value, {'from': 'elsewhere'});
      system.remove(tester);
    });

    testWidgets('says so when there is nothing to paste', (tester) async {
      system.install(tester);
      var editor = ObjectEditor({'a': 1});
      await tester.pumpWidget(
        _app(ObjectEditorView(editor: editor, clipboard: clipboard)),
      );

      await _openMenu(tester, 'a');
      await tester.tap(find.text('Paste here'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing to paste'), findsOneWidget);
      expect(editor.value, {'a': 1});
      system.remove(tester);
    });

    testWidgets('a read only view copies but does not paste', (tester) async {
      system.install(tester);
      var editor = ObjectEditor({'a': 1});
      await tester.pumpWidget(
        _app(
          ObjectEditorView(
            editor: editor,
            clipboard: clipboard,
            readOnly: true,
          ),
        ),
      );

      await _openMenu(tester, 'a');
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Paste here'), findsNothing);
      expect(find.text('Change type'), findsNothing);
      expect(find.text('Remove'), findsNothing);

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(clipboard.isNotEmpty, isTrue);
      system.remove(tester);
    });
  });

  group('the whole object', () {
    testWidgets('copies and pastes it from the app bar', (tester) async {
      system.install(tester);
      var from = MemoryObjectSource(title: 'from', value: {'a': 1});
      await tester.pumpWidget(
        MaterialApp(
          home: ObjectEditorScreen(source: from, clipboard: clipboard),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.copy_all_outlined));
      await tester.pumpAndSettle();
      expect(clipboard.isNotEmpty, isTrue);

      var to = MemoryObjectSource(title: 'to', value: {'b': 2});
      await tester.pumpWidget(
        MaterialApp(
          home: ObjectEditorScreen(source: to, clipboard: clipboard),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.paste));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(await to.read(), {'a': 1});
      await from.close();
      await to.close();
      system.remove(tester);
    });

    testWidgets('a read only source shows no paste and no save', (
      tester,
    ) async {
      system.install(tester);
      var source = MemoryObjectSource(
        title: 'viewer',
        value: {'a': 1},
        isReadOnly: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ObjectEditorScreen(source: source, clipboard: clipboard),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byIcon(Icons.copy_all_outlined), findsOneWidget);
      expect(find.byIcon(Icons.paste), findsNothing);
      expect(find.byIcon(Icons.save), findsNothing);
      await source.close();
      system.remove(tester);
    });
  });
}

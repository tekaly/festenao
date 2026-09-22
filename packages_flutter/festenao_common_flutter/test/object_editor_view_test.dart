import 'package:festenao_common_flutter/object_editor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// The row of the field named [name]: every row is a [Row], and the root has
/// one of its own, so rows are targeted by name rather than by index.
Finder _row(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(Row)).first;

/// Opens the menu of the row named [name].
Future<void> _openMenu(WidgetTester tester, String name) async {
  await tester.tap(
    find.descendant(of: _row(name), matching: find.byIcon(Icons.more_vert)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('ObjectEditorView', () {
    testWidgets('shows a row per field', (tester) async {
      var editor = ObjectEditor({
        'name': 'test',
        'count': 1,
        'enabled': true,
        'nested': {'a': 1},
      });
      await tester.pumpWidget(_app(ObjectEditorView(editor: editor)));

      expect(find.text('name'), findsOneWidget);
      expect(find.text('count'), findsOneWidget);
      expect(find.text('enabled'), findsOneWidget);
      expect(find.text('nested'), findsOneWidget);
      // The nested map is expanded, its field shows too.
      expect(find.text('a'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('edits a string through its field', (tester) async {
      var editor = ObjectEditor({'name': 'test'});
      await tester.pumpWidget(_app(ObjectEditorView(editor: editor)));

      await tester.enterText(find.byType(TextField).first, 'edited');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(editor.value, {'name': 'edited'});
      expect(editor.isDirty, isTrue);
    });

    testWidgets('refuses a text the type cannot parse', (tester) async {
      var editor = ObjectEditor({'count': 1});
      await tester.pumpWidget(_app(ObjectEditorView(editor: editor)));

      await tester.enterText(find.byType(TextField).first, 'not a number');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(editor.value, {'count': 1});
      expect(editor.isDirty, isFalse);
      expect(find.text('Not an integer'), findsOneWidget);
    });

    testWidgets('toggles a boolean', (tester) async {
      var editor = ObjectEditor({'enabled': false});
      await tester.pumpWidget(_app(ObjectEditorView(editor: editor)));

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(editor.value, {'enabled': true});
    });

    testWidgets('collapses a container', (tester) async {
      var editor = ObjectEditor({
        'nested': {'a': 1},
      });
      await tester.pumpWidget(_app(ObjectEditorView(editor: editor)));
      expect(find.text('a'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: _row('nested'),
          matching: find.byIcon(Icons.arrow_drop_down),
        ),
      );
      await tester.pump();
      expect(find.text('a'), findsNothing);
    });

    testWidgets('adds a field through the dialogs', (tester) async {
      var editor = ObjectEditor(<String, Object?>{});
      await tester.pumpWidget(_app(ObjectEditorView(editor: editor)));

      await tester.tap(find.text('Add field'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'title');
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('String'));
      await tester.pumpAndSettle();

      expect(editor.value, {'title': ''});
    });

    testWidgets('removes a field through the menu', (tester) async {
      var editor = ObjectEditor({'name': 'test', 'count': 1});
      await tester.pumpWidget(_app(ObjectEditorView(editor: editor)));

      await _openMenu(tester, 'name');
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(editor.value, {'count': 1});
    });

    testWidgets('changes a type through the menu', (tester) async {
      var editor = ObjectEditor({'count': '1'});
      await tester.pumpWidget(_app(ObjectEditorView(editor: editor)));

      await _openMenu(tester, 'count');
      await tester.tap(find.text('Change type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Integer'));
      await tester.pumpAndSettle();

      expect(editor.value, {'count': 0});
    });

    testWidgets('edits a date with the picker', (tester) async {
      var editor = ObjectEditor({'when': DateTime.utc(2024, 1, 2)});
      await tester.pumpWidget(_app(ObjectEditorView(editor: editor)));

      expect(find.byIcon(Icons.event), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        '2025-03-04T00:00:00.000Z',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(editor.value, {'when': DateTime.utc(2025, 3, 4)});
    });

    testWidgets('shows a read only tree without editors', (tester) async {
      var editor = ObjectEditor({'name': 'test'});
      await tester.pumpWidget(
        _app(ObjectEditorView(editor: editor, readOnly: true)),
      );

      expect(find.byType(TextField), findsNothing);
      expect(find.text('"test"'), findsOneWidget);
      expect(find.text('Add field'), findsNothing);
      // The root has a row of its own, showing what the tree holds.
      expect(find.text('{1 field}'), findsOneWidget);
    });
  });

  group('ObjectEditorScreen', () {
    testWidgets('loads, edits and saves a source', (tester) async {
      var source = MemoryObjectSource(title: 'demo', value: {'name': 'test'});
      await tester.pumpWidget(
        MaterialApp(home: ObjectEditorScreen(source: source)),
      );
      await tester.pumpAndSettle();

      expect(find.text('demo'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'edited');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();

      expect(await source.read(), {'name': 'edited'});
      await source.close();
    });
  });
}

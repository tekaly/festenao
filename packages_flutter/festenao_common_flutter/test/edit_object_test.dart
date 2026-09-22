import 'package:cv/cv.dart';
import 'package:festenao_common_flutter/object_editor_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A screen with a button opening the editor, so what it answers is checked
/// the way an app would receive it.
class _Host extends StatefulWidget {
  final Object? value;
  final CvModel? model;

  const _Host({super.key, this.value, this.model});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Object? result;
  var called = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          var model = widget.model;
          if (model != null) {
            result = await editCvModel(context, model);
          } else {
            result = await editObject(context, widget.value);
          }
          called = true;
          setState(() {});
        },
        child: const Text('edit'),
      ),
    ),
  );
}

/// The row of the field named [name].
Finder _row(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(Row)).last;

class _Settings extends CvModelBase {
  final name = CvField<String>('name');
  final count = CvField<int>('count');

  @override
  CvFields get fields => [name, count];
}

void main() {
  group('editObject', () {
    testWidgets('answers the edited object once saved', (tester) async {
      var key = GlobalKey<_HostState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _Host(key: key, value: const {'name': 'test'}),
        ),
      );
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'edited');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(key.currentState!.result, {'name': 'edited'});
    });

    testWidgets('answers null when it was left without saving', (tester) async {
      var key = GlobalKey<_HostState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _Host(key: key, value: const {'name': 'test'}),
        ),
      );
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'edited');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(key.currentState!.called, isTrue);
      expect(key.currentState!.result, isNull);
    });

    testWidgets('leaves the object it was given alone', (tester) async {
      var value = {'name': 'test'};
      var key = GlobalKey<_HostState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _Host(key: key, value: value),
        ),
      );
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'edited');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(value, {'name': 'test'});
      expect(key.currentState!.result, {'name': 'edited'});
    });

    testWidgets('edits a list as well as a map', (tester) async {
      var key = GlobalKey<_HostState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _Host(key: key, value: const ['a', 'b']),
        ),
      );
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'a2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(key.currentState!.result, ['a2', 'b']);
    });
  });

  group('editCvModel', () {
    testWidgets('feeds the edited map back into the model', (tester) async {
      var settings = _Settings()
        ..name.v = 'test'
        ..count.v = 1;
      var key = GlobalKey<_HostState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _Host(key: key, model: settings),
        ),
      );
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'edited');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.save));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(key.currentState!.result, isTrue);
      expect(settings.name.v, 'edited');
      expect(settings.count.v, 1);
    });

    testWidgets('offers the fields the model declares', (tester) async {
      var settings = _Settings()..name.v = 'test';
      await tester.pumpWidget(MaterialApp(home: _Host(model: settings)));
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add field'));
      await tester.pumpAndSettle();
      // The field the model declares and the map does not hold yet.
      expect(find.text('count'), findsOneWidget);

      await tester.tap(find.text('count'));
      await tester.pumpAndSettle();
      // Its type came from the model, so no type selector was shown: the
      // other types would be listed in one, and the model declares no bool.
      expect(find.text('Boolean'), findsNothing);
      // And the field it added is an int one, whose editor hints as much.
      expect(find.text('count'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: _row('count'),
                matching: find.byType(TextField),
              ),
            )
            .decoration!
            .hintText,
        'Integer',
      );
    });
  });
}

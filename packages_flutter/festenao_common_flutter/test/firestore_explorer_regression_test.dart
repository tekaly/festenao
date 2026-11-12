import 'package:festenao_common_flutter/firestore_explorer_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';

/// See the file system explorer tests: the backend is really asynchronous.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  group('FirestoreExplorerScreen', () {
    testWidgets('adds a collection the listing does not show', (tester) async {
      await tester.runAsync(() async {
        // ignore: deprecated_member_use
        var firestore = newFirestoreMemory();
        await firestore.doc('user/alice').set({'name': 'Alice'});
        await firestore.doc('user/alice/note/first').set({'title': 'First'});
        await tester.pumpWidget(
          MaterialApp(home: FirestoreExplorerScreen(firestore: firestore)),
        );
        await _settle(tester);
        expect(find.text('user'), findsOneWidget);

        Future<void> add(String path) async {
          await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
          await _settle(tester);
          await tester.enterText(find.byType(TextField), path);
          await tester.tap(find.text('Ok'));
          await _settle(tester);
        }

        await add('user/alice/note');
        expect(find.text('user'), findsOneWidget);
        expect(find.text('user/alice/note'), findsOneWidget);

        // One already listed is not listed twice.
        await add('user');
        expect(find.text('user'), findsOneWidget);

        await tester.tap(find.text('user/alice/note'));
        await _settle(tester);
        expect(find.text('first'), findsOneWidget);
      });
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

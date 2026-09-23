import 'dart:typed_data';

import 'package:festenao_common_flutter/firestore_explorer_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';

/// See the file system explorer tests: the backend is really asynchronous.
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

Future<Firestore> _newFirestore() async {
  // ignore: deprecated_member_use
  var firestore = newFirestoreMemory();
  await firestore.doc('config/main').set({
    'name': 'test',
    'when': Timestamp.parse('2024-01-02T03:04:05.000Z'),
    'data': Blob(Uint8List.fromList([1, 2, 3, 4])),
    'where': const GeoPoint(1.5, 2.5),
    'other': firestore.doc('config/second'),
  });
  await firestore.doc('config/second').set({'name': 'second'});
  return firestore;
}

Future<void> _pump(
  WidgetTester tester,
  Firestore firestore, {
  bool isReadOnly = false,
  List<String>? collectionPaths,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FirestoreExplorerScreen(
        firestore: firestore,
        isReadOnly: isReadOnly,
        collectionPaths: collectionPaths,
      ),
    ),
  );
  await _settle(tester);
}

void main() {
  group('FirestoreExplorerScreen', () {
    _testWidgets('lists the collections and opens a document', (tester) async {
      var firestore = await _newFirestore();
      await _pump(tester, firestore);

      expect(find.text('config'), findsOneWidget);
      await tester.tap(find.text('config'));
      await _settle(tester);

      expect(find.text('main'), findsOneWidget);
      await tester.tap(find.text('main'));
      await _settle(tester);
      expect(find.text('name'), findsOneWidget);
    });

    _testWidgets('edits each firestore type with what fits it', (tester) async {
      var firestore = await _newFirestore();
      await _pump(tester, firestore);
      await tester.tap(find.text('config'));
      await _settle(tester);
      await tester.tap(find.text('main'));
      await _settle(tester);

      // A timestamp gets its date picker.
      expect(find.text('when'), findsOneWidget);
      expect(find.byIcon(Icons.event), findsOneWidget);
      expect(find.text('2024-01-02T03:04:05.000Z'), findsOneWidget);
      // A blob edits as base64.
      expect(find.text('AQIDBA=='), findsOneWidget);
      // A geo point as latitude,longitude.
      expect(find.text('1.5,2.5'), findsOneWidget);
      // A reference as its path.
      expect(find.text('config/second'), findsOneWidget);
    });

    _testWidgets('writes a firestore type back as that type', (tester) async {
      var firestore = await _newFirestore();
      await _pump(tester, firestore);
      await tester.tap(find.text('config'));
      await _settle(tester);
      await tester.tap(find.text('main'));
      await _settle(tester);

      await tester.enterText(
        find.widgetWithText(TextField, '1.5,2.5'),
        '3.5,4.5',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.save));
      await _settle(tester);

      var data = (await firestore.doc('config/main').get()).data;
      expect(data['where'], const GeoPoint(3.5, 4.5));
      // The others kept their types through the round trip.
      expect(data['when'], Timestamp.parse('2024-01-02T03:04:05.000Z'));
      expect(data['data'], Blob(Uint8List.fromList([1, 2, 3, 4])));
      expect((data['other'] as DocumentReference).path, 'config/second');
    });

    _testWidgets('shows the hidden documents on demand', (tester) async {
      var firestore = await _newFirestore();
      // No data of its own, only a sub-collection.
      await firestore.doc('config/ghost/items/a').set({'name': 'a'});
      await _pump(tester, firestore);
      await tester.tap(find.text('config'));
      await _settle(tester);

      expect(find.text('main'), findsOneWidget);
      expect(find.text('ghost'), findsNothing);

      await tester.tap(find.byTooltip('Show hidden records'));
      await _settle(tester);
      expect(find.text('ghost'), findsOneWidget);
      expect(find.text('hidden'), findsOneWidget);
      expect(find.text('1 hidden'), findsOneWidget);
      expect(find.text('3 records'), findsOneWidget);
      // The others are still listed, not marked.
      expect(find.text('main'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);

      await tester.tap(find.byTooltip('Hide hidden records'));
      await _settle(tester);
      expect(find.text('ghost'), findsNothing);
      expect(find.text('2 records'), findsOneWidget);
    });

    _testWidgets('walks down the sub-collections of a document', (
      tester,
    ) async {
      var firestore = await _newFirestore();
      await firestore.doc('config/main/items/a').set({'label': 'item a'});
      await _pump(tester, firestore);
      await tester.tap(find.text('config'));
      await _settle(tester);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'main'),
          matching: find.byTooltip('Sub-collections'),
        ),
      );
      await _settle(tester);
      expect(find.text('config/main/items'), findsOneWidget);

      // The document itself is one tap away.
      await tester.tap(find.byTooltip('Open config/main'));
      await _settle(tester);
      expect(find.text('name'), findsOneWidget);
      expect(find.text('test'), findsOneWidget);
      await tester.pageBack();
      await _settle(tester);

      await tester.tap(find.text('config/main/items'));
      await _settle(tester);
      await tester.tap(find.text('a'));
      await _settle(tester);
      expect(find.text('label'), findsOneWidget);
      expect(find.text('item a'), findsOneWidget);
    });

    _testWidgets('a hidden document opens its sub-collections', (tester) async {
      var firestore = await _newFirestore();
      await firestore.doc('config/ghost/items/a').set({'label': 'item a'});
      await _pump(tester, firestore);
      await tester.tap(find.text('config'));
      await _settle(tester);
      await tester.tap(find.byTooltip('Show hidden records'));
      await _settle(tester);

      await tester.tap(find.text('ghost'));
      await _settle(tester);
      expect(find.text('config/ghost/items'), findsOneWidget);
    });

    _testWidgets('a read only explorer writes nothing', (tester) async {
      var firestore = await _newFirestore();
      await _pump(tester, firestore, isReadOnly: true);

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      await tester.tap(find.text('config'));
      await _settle(tester);
      // No way to add or delete a document.
      expect(find.byIcon(Icons.add), findsNothing);

      await tester.tap(find.text('main'));
      await _settle(tester);
      expect(find.byIcon(Icons.save), findsNothing);
      expect(find.byIcon(Icons.paste), findsNothing);
      // Copying a document still works.
      expect(find.byIcon(Icons.copy_all_outlined), findsOneWidget);
    });

    _testWidgets('shows the collection paths it is given', (tester) async {
      var firestore = await _newFirestore();
      await _pump(tester, firestore, collectionPaths: ['config']);

      expect(find.text('config'), findsOneWidget);
      await tester.tap(find.text('config'));
      await _settle(tester);
      expect(find.text('main'), findsOneWidget);
    });

    _testWidgets('names a collection by hand', (tester) async {
      var firestore = await _newFirestore();
      await _pump(tester, firestore, collectionPaths: []);

      expect(find.text('No collection named yet, add one'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.create_new_folder_outlined));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'config');
      await tester.tap(find.text('Ok'));
      await _settle(tester);

      expect(find.text('config'), findsOneWidget);
    });

    _testWidgets('opens a document by its path', (tester) async {
      var firestore = await _newFirestore();
      await _pump(tester, firestore);

      await tester.tap(find.byIcon(Icons.find_in_page_outlined));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'config/second');
      await tester.tap(find.text('Ok'));
      await _settle(tester);

      expect(find.text('name'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
    });

    _testWidgets('says when a path names a collection, not a document', (
      tester,
    ) async {
      var firestore = await _newFirestore();
      await _pump(tester, firestore);

      await tester.tap(find.byIcon(Icons.find_in_page_outlined));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), 'config');
      await tester.tap(find.text('Ok'));
      await _settle(tester);

      expect(
        find.text('config is a collection, not a document'),
        findsOneWidget,
      );
    });
  });

  group('the reference type', () {
    _testWidgets('starts a new one on a path that can be edited', (
      tester,
    ) async {
      var firestore = await _newFirestore();
      await _pump(tester, firestore);
      await tester.tap(find.text('config'));
      await _settle(tester);
      await tester.tap(find.text('second'));
      await _settle(tester);

      // Switch the name field to a reference.
      await tester.tap(
        find.descendant(
          of: find
              .ancestor(of: find.text('name'), matching: find.byType(Row))
              .last,
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Change type'));
      await _settle(tester);
      await tester.tap(find.text('Reference'));
      await _settle(tester);

      // It is a real reference on a placeholder path, not a null.
      expect(find.text(firestoreNewReferencePath), findsOneWidget);
    });
  });
}

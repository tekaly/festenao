import 'dart:convert';

import 'package:festenao_common_flutter/admin_explorer_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/sdb.dart';

/// A service account that looks like one, without being a real key.
String _serviceAccount({String projectId = 'demo-project'}) => jsonEncode({
  'type': 'service_account',
  'project_id': projectId,
  'private_key_id': 'abc',
  'private_key':
      '-----BEGIN PRIVATE KEY-----\nnot-a-key\n-----END PRIVATE KEY-----\n',
  'client_email': 'admin@$projectId.iam.gserviceaccount.com',
  'client_id': '1',
});

/// See the file system explorer tests: sdb is really asynchronous.
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

var _dbIndex = 0;

Future<AdminCredentialsDb> _newDb() =>
    AdminCredentialsDb.open(sdbFactoryMemory, name: 'admin_${_dbIndex++}.db');

void main() {
  group('the service account', () {
    test('reads its project id', () {
      expect(adminServiceAccountProjectId(_serviceAccount()), 'demo-project');
      expect(adminServiceAccountProjectId('not json'), isNull);
      expect(adminServiceAccountProjectId(null), isNull);
    });

    test('says what is wrong with it', () {
      expect(adminServiceAccountError(_serviceAccount()), isNull);
      expect(
        adminServiceAccountError(null),
        'The service account json is empty',
      );
      expect(
        adminServiceAccountError('not json'),
        'The service account is not a json object',
      );
      expect(
        adminServiceAccountError(jsonEncode({'project_id': 'p'})),
        'The service account has no client_email',
      );
    });
  });

  group('AdminCredentialsDb', () {
    test('adds, reads, updates and deletes', () async {
      var db = await _newDb();
      var id = await db.add(label: 'Demo', serviceAccount: _serviceAccount());

      var credentials = (await db.get(id))!;
      expect(credentials.label.v, 'Demo');
      // The project id came from the service account.
      expect(credentials.projectId.v, 'demo-project');
      expect(credentials.displayName, 'Demo');
      expect(credentials.serviceAccountMap!['type'], 'service_account');

      await db.put(
        id,
        label: '',
        serviceAccount: _serviceAccount(projectId: 'other-project'),
      );
      var updated = (await db.get(id))!;
      expect(updated.projectId.v, 'other-project');
      // No label: the project id stands in for it.
      expect(updated.displayName, 'other-project');

      expect((await db.list()).length, 1);
      await db.delete(id);
      expect(await db.list(), isEmpty);
      await db.close();
    });

    test('lists them by name', () async {
      var db = await _newDb();
      await db.add(label: 'zulu', serviceAccount: _serviceAccount());
      await db.add(label: 'alpha', serviceAccount: _serviceAccount());
      expect((await db.list()).map((credentials) => credentials.displayName), [
        'alpha',
        'zulu',
      ]);
      await db.close();
    });

    test('remembers which one is selected', () async {
      var db = await _newDb();
      expect(await db.current(), isNull);
      var id = await db.add(label: 'Demo', serviceAccount: _serviceAccount());

      await db.setCurrentId(id);
      expect(await db.currentId(), id);
      expect((await db.current())!.label.v, 'Demo');

      // Deleting the selected one forgets the selection.
      await db.delete(id);
      expect(await db.currentId(), isNull);
      expect(await db.current(), isNull);
      await db.close();
    });

    test('is a plain sdb database, explorable like any other', () async {
      var db = await _newDb();
      await db.add(label: 'Demo', serviceAccount: _serviceAccount());
      var repository = SdbObjectRepository(db.database);
      var collections = await repository.listCollections();
      expect(
        collections.map((collection) => collection.name),
        containsAll(['credentials', 'settings']),
      );
      await db.close();
    });
  });

  group('AdminCredentialsScreen', () {
    _testWidgets('adds a service account and selects it', (tester) async {
      var db = await _newDb();
      await tester.pumpWidget(
        MaterialApp(home: AdminCredentialsScreen(credentialsDb: db)),
      );
      await _settle(tester);
      expect(
        find.text('No credentials yet, add a service account'),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.add));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).first, 'Demo');
      await tester.enterText(find.byType(TextField).last, _serviceAccount());
      await tester.tap(find.byIcon(Icons.save));
      await _settle(tester);

      expect(find.text('Demo'), findsOneWidget);
      expect(find.text('demo-project'), findsOneWidget);
      // Nothing selected until it is tapped.
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

      await tester.tap(find.text('Demo'));
      await _settle(tester);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect((await db.current())!.label.v, 'Demo');
      await db.close();
    });

    _testWidgets('refuses a service account that is not one', (tester) async {
      var db = await _newDb();
      await tester.pumpWidget(
        MaterialApp(home: AdminCredentialsScreen(credentialsDb: db)),
      );
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.add));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, 'not json');
      await tester.tap(find.byIcon(Icons.save));
      await _settle(tester);

      expect(
        find.text('The service account is not a json object'),
        findsOneWidget,
      );
      expect(await db.list(), isEmpty);
      await db.close();
    });

    _testWidgets('deletes one', (tester) async {
      var db = await _newDb();
      await db.add(label: 'Demo', serviceAccount: _serviceAccount());
      await tester.pumpWidget(
        MaterialApp(home: AdminCredentialsScreen(credentialsDb: db)),
      );
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.more_vert));
      await _settle(tester);
      await tester.tap(find.text('Delete'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await _settle(tester);

      expect(await db.list(), isEmpty);
      await db.close();
    });
  });

  group('AdminExplorerScreen', () {
    _testWidgets('offers every explorer, firestore needing credentials', (
      tester,
    ) async {
      var db = await _newDb();
      await tester.pumpWidget(
        MaterialApp(home: AdminExplorerScreen(credentialsDb: db)),
      );
      await _settle(tester);

      expect(find.text('Firestore explorer'), findsOneWidget);
      expect(find.text('Users explorer'), findsOneWidget);
      expect(find.text('File system explorer'), findsOneWidget);
      expect(find.text('Sembast explorer'), findsOneWidget);
      expect(find.text('Sdb explorer'), findsOneWidget);
      expect(find.text('Any database'), findsOneWidget);
      // Without credentials, firestore and the users say so rather than
      // opening.
      expect(find.text('None selected'), findsOneWidget);
      expect(find.text('Pick a set of credentials first'), findsNWidgets(2));
      await db.close();
    });

    _testWidgets('names the selected credentials', (tester) async {
      var db = await _newDb();
      var id = await db.add(label: 'Demo', serviceAccount: _serviceAccount());
      await db.setCurrentId(id);
      await tester.pumpWidget(
        MaterialApp(home: AdminExplorerScreen(credentialsDb: db)),
      );
      await _settle(tester);

      expect(find.text('Demo (demo-project)'), findsOneWidget);
      expect(find.text('As Demo, backup included'), findsOneWidget);
      expect(find.text('As Demo, found by uid'), findsOneWidget);
      await db.close();
    });
  });

  group('admin roots', () {
    test('offer the whole file system and the home directory', () {
      var roots = adminFileSystemRoots(homePath: '/home/demo');
      expect(roots.first.name, 'Whole file system');
      expect(roots[1].name, 'Home');
      expect(roots[1].description, '/home/demo');
      // The app roots follow.
      expect(
        roots.map((root) => root.name),
        containsAll(['Documents', 'Support', 'Memory']),
      );
    });

    test('leave the home one out when there is none', () {
      var roots = adminFileSystemRoots();
      expect(roots.map((root) => root.name), isNot(contains('Home')));
    });
  });
}

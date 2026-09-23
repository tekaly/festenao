import 'package:festenao_common_flutter/firebase_users_explorer_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_firebase_auth_sdb/auth_sdb.dart';
import 'package:tekartik_firebase_auth_sembast/auth_sembast.dart'
    show newFirebaseAuthMemory;

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
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      try {
        await body(tester);
      } finally {
        await tester.binding.setSurfaceSize(null);
      }
    });
  });
}

/// The in memory sdb auth, which lists its users, with the demo ones.
Future<FirebaseAuthSdb> _newAuth() async {
  var auth = newFirebaseAuthSdbMemory() as FirebaseAuthSdb;
  await fillDemoFirebaseUsers(auth);
  return auth;
}

Future<void> _pump(
  WidgetTester tester,
  FirebaseAuth auth, {
  bool isReadOnly = false,
  int pageSize = 100,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FirebaseUsersExplorerScreen(
        explorer: FirebaseUsersExplorer(
          auth: auth,
          isReadOnly: isReadOnly,
          pageSize: pageSize,
        ),
        title: 'demo',
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _find(WidgetTester tester, String query) async {
  await tester.tap(find.byTooltip('Find a user'));
  await _settle(tester);
  await tester.enterText(find.byType(TextField), query);
  await tester.tap(find.text('Ok'));
  await _settle(tester);
}

void main() {
  group('FirebaseUsersExplorerScreen', () {
    _testWidgets('lists the users and what is worth noticing', (tester) async {
      var auth = await _newAuth();
      await _pump(tester, auth);

      expect(find.text('listed'), findsOneWidget);
      expect(find.text('6 users'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('alice@example.com · alice'), findsOneWidget);
      expect(find.text(demoFirebaseAnonymousUid), findsOneWidget);
      expect(find.text('anonymous'), findsOneWidget);
      expect(find.text('disabled'), findsOneWidget);
      // Carol's email is not verified.
      expect(find.text('unverified'), findsOneWidget);
      expect(find.byIcon(Icons.person_off_outlined), findsOneWidget);
      await auth.app.delete();
    });

    _testWidgets('shows every field a user holds', (tester) async {
      var auth = await _newAuth();
      await _pump(tester, auth);

      await tester.tap(find.text('Alice'));
      await _settle(tester);
      expect(find.text('uid'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('photoURL'), findsOneWidget);
      expect(find.text('https://example.com/alice.png'), findsOneWidget);
      expect(find.text('emailVerified'), findsOneWidget);
      await auth.app.delete();
    });

    _testWidgets('loads the users page by page', (tester) async {
      var auth = await _newAuth();
      await _pump(tester, auth, pageSize: 4);

      expect(find.text('4+ users'), findsOneWidget);
      expect(find.text('Dave (disabled)'), findsNothing);
      await tester.tap(find.text('Load more'));
      await _settle(tester);
      expect(find.text('6 users'), findsOneWidget);
      expect(find.text('Dave (disabled)'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
      await auth.app.delete();
    });

    _testWidgets('finds a user by email', (tester) async {
      var auth = await _newAuth();
      await _pump(tester, auth);

      await _find(tester, 'bob@example.com');
      expect(find.text('bob'), findsWidgets);
      expect(find.text('displayName'), findsOneWidget);

      await tester.pageBack();
      await _settle(tester);
      await _find(tester, 'nobody@example.com');
      expect(find.text('No user nobody@example.com'), findsOneWidget);
      await auth.app.delete();
    });

    _testWidgets('creates a user, then deletes it', (tester) async {
      var auth = await _newAuth();
      await _pump(tester, auth);

      await tester.tap(find.byTooltip('New user'));
      await _settle(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'frank@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        'Frank',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Uid (empty for a generated one)'),
        'frank',
      );
      await tester.tap(find.text('Create'));
      await _settle(tester);
      // The new user opens straight away.
      expect(find.text('frank@example.com'), findsOneWidget);
      expect((await auth.getUser('frank'))!.displayName, 'Frank');

      await tester.tap(find.byTooltip('Delete'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await _settle(tester);
      expect(await auth.getUser('frank'), isNull);
      // Back to the list, without it.
      expect(find.text('6 users'), findsOneWidget);
      expect(find.text('Frank'), findsNothing);
      await auth.app.delete();
    });

    _testWidgets('a read only explorer writes nothing', (tester) async {
      var auth = await _newAuth();
      await _pump(tester, auth, isReadOnly: true);

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.byTooltip('New user'), findsNothing);
      await tester.tap(find.text('Alice'));
      await _settle(tester);
      expect(find.byTooltip('Delete'), findsNothing);
      expect(find.byTooltip('Copy uid'), findsOneWidget);
      await auth.app.delete();
    });

    _testWidgets('finds by uid what it cannot list', (tester) async {
      // The sembast backend, like the rest api, cannot list its users.
      var auth = newFirebaseAuthMemory() as FirebaseAuthAdmin;
      await auth.createUser(
        FirebaseAuthCreateUserRequest(uid: 'alice', email: 'alice@example.com'),
      );
      await _pump(tester, auth);

      expect(find.text('lookup only'), findsOneWidget);
      expect(
        find.text(
          'This auth cannot list its users, find one by its uid or email',
        ),
        findsOneWidget,
      );
      await _find(tester, 'alice');
      expect(find.text('alice@example.com'), findsWidgets);
      await auth.app.delete();
    });
  });
}

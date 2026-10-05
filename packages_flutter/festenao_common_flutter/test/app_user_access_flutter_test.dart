import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common_flutter/app_user_access_flutter.dart';
import 'package:festenao_common_flutter/firebase_users_explorer_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_firebase_auth_sdb/auth_sdb.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';

/// The backend is really asynchronous (see the users explorer tests).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  const appId = 'my_app-dev';

  testWidgets('app user access', (tester) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      try {
        var firestore = newFirestoreMemory();
        var auth = newFirebaseAuthSdbMemory() as FirebaseAuthSdb;
        await fillDemoFirebaseUsers(auth);
        await tester.pumpWidget(
          MaterialApp(
            home: FestenaoAppUserAccessScreen(
              firestore: firestore,
              appId: appId,
              auth: auth,
            ),
          ),
        );
        await _settle(tester);
        expect(find.text('No user has an access yet'), findsOneWidget);

        // Add an admin by email: the account must exist.
        await tester.tap(find.text('Add an admin'));
        await _settle(tester);
        await tester.enterText(find.byType(TextField), 'nobody@example.com');
        await tester.tap(find.text('Add'));
        await _settle(tester);
        expect(
          find.text('Bad state: No user nobody@example.com'),
          findsOneWidget,
        );

        await tester.tap(find.text('Add an admin'));
        await _settle(tester);
        await tester.enterText(find.byType(TextField), 'alice@example.com');
        await tester.tap(find.text('Add'));
        await _settle(tester);
        expect(find.text('alice@example.com'), findsOneWidget);
        var alice = (await auth.getUserByEmail('alice@example.com'))!;
        var ref = festenaoAppUserAccessCollection(appId)
            .cast<TkCmsEditedFsUserAccess>()
            .doc(alice.uid);
        var access = await ref.get(firestore);
        expect(access.isAdmin, isTrue);
        expect(access.isWrite, isTrue);
        expect(access.isRead, isTrue);
        expect(access.role.v, roleAdmin);
        expect(access.name.v, 'alice@example.com');

        // No longer an admin, then no access at all.
        await tester.tap(find.byType(PopupMenuButton<String>));
        await _settle(tester);
        await tester.tap(find.text('Remove admin'));
        await _settle(tester);
        access = await ref.get(firestore);
        expect(access.isAdmin, isFalse);
        expect(access.isWrite, isFalse);
        expect(access.isRead, isTrue);
        expect(access.role.v, roleUser);

        await tester.tap(find.byType(PopupMenuButton<String>));
        await _settle(tester);
        await tester.tap(find.text('Remove the access'));
        await _settle(tester);
        await tester.tap(find.text('Remove'));
        await _settle(tester);
        expect((await ref.get(firestore)).exists, isFalse);
        expect(find.text('No user has an access yet'), findsOneWidget);
      } finally {
        await tester.binding.setSurfaceSize(null);
      }
    });
  });
}

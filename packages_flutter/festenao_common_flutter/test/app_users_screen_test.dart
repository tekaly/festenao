import 'package:festenao_common_flutter/app_users_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_firebase_auth_sdb/auth_sdb.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';

/// The memory backends answer asynchronously: real time between pumps.
Future<void> _settle(WidgetTester tester, {int count = 20}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  testWidgets('purge more than 200 anonymous users not seen for 365 days', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(const Size(1200, 1200));
      try {
        // ignore: deprecated_member_use
        var firestore = newFirestoreMemory();
        var auth = newFirebaseAuthSdbMemory();
        // More than the default limit (200) of a purge.
        const userCount = 250;
        var collectionPath = 'app/test/$tkCmsFsAppUserCollectionId';
        var batch = firestore.batch();
        for (var i = 0; i < userCount; i++) {
          batch.set(firestore.doc('$collectionPath/u$i'), {
            'lastSeen': Timestamp.parse('2020-01-01T00:00:00Z'),
            'created': Timestamp.parse('2020-01-01T00:00:00Z'),
            'anonymous': true,
          });
        }
        await batch.commit();
        var appUsers = TkCmsAppUsersFirestore(
          firestore: firestore,
          auth: auth,
          app: 'test',
        );
        await tester.pumpWidget(
          MaterialApp(
            home: AppUsersScreen(appUsers: appUsers, title: 'test'),
          ),
        );
        await _settle(tester);
        await tester.tap(find.byTooltip('Purge'));
        await _settle(tester, count: 5);
        await tester.tap(find.text('Purge anonymous users not seen since…'));
        await _settle(tester, count: 5);
        // 365 days, the default.
        await tester.tap(find.text('Ok'));
        await _settle(tester, count: 40);
        // The dry run lists them all.
        expect(find.text('Purge $userCount anonymous users'), findsOneWidget);
        await tester.tap(find.text('Purge'));
        await _settle(tester, count: 100);
        var left = (await firestore.collection(collectionPath).get()).docs;
        expect(left, isEmpty);
        await tester.pumpWidget(const SizedBox());
      } finally {
        await tester.binding.setSurfaceSize(null);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}

import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common_flutter/admin_explorer_flutter.dart';
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

void main() {
  late Firestore firestore;
  late FirebaseAuthSdb auth;
  late FestenaoAppsAdmin admin;

  Future<void> setUpData() async {
    firestore = newFirestoreMemory();
    auth = newFirebaseAuthSdbMemory() as FirebaseAuthSdb;
    await fillDemoFirebaseUsers(auth);
    admin = FestenaoAppsAdmin(
      firestore: firestore,
      // As the admin sdk: an app known by its access only.
      listDocumentIds: (path) async =>
          path == 'access/app/entity_id' ? ['ghost-app'] : <String>[],
    );
    await admin.appAccess
        .fsEntityRef('my-app')
        .set(firestore, TkCmsFsApp()..name.v = 'My app');
    await admin
        .projectAccess('my-app')
        .fsEntityRef('p1')
        .set(firestore, FsProject()..name.v = 'Project 1');
  }

  Future<FestenaoUserAccessGrant?> grantOf(
    TkCmsFirestoreDatabaseServiceEntityAccess entityAccess,
    String entityId,
    String userId,
  ) async {
    var entitySide = await entityAccess
        .fsEntityUserAccessRef(entityId, userId)
        .get(firestore);
    var userSide = await entityAccess
        .fsUserEntityAccessRef(userId, entityId)
        .get(firestore);
    var grant = entitySide.exists
        ? FestenaoUserAccessGrant.of(entitySide)
        : null;
    // Both sides always agree.
    expect(
      userSide.exists ? FestenaoUserAccessGrant.of(userSide) : null,
      grant,
    );
    return grant;
  }

  _testWidgets('apps, app users, super admin', (tester) async {
    await setUpData();
    await tester.pumpWidget(
      MaterialApp(
        home: AdminAppsScreen(admin: admin, auth: auth),
      ),
    );
    await _settle(tester);
    expect(find.text('my-app'), findsOneWidget);
    expect(find.text('My app'), findsOneWidget);
    expect(find.text('ghost-app'), findsOneWidget);
    expect(find.text('no document'), findsOneWidget);

    await tester.tap(find.text('my-app'));
    await _settle(tester);
    expect(find.text('0 users'), findsOneWidget);
    expect(find.text('Project 1'), findsOneWidget);

    // Alice made a super admin of the app, by email.
    await tester.tap(find.text('Users'));
    await _settle(tester);
    expect(find.text('No user has an access yet'), findsOneWidget);
    await tester.tap(find.text('Add a user'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'alice@example.com');
    await tester.tap(
      find.byType(DropdownButtonFormField<FestenaoUserAccessGrant>),
    );
    await _settle(tester);
    await tester.tap(find.text('super admin').last);
    await _settle(tester);
    await tester.tap(find.text('Give'));
    await _settle(tester);
    expect(
      await grantOf(admin.appAccess, 'my-app', 'alice'),
      FestenaoUserAccessGrant.superAdmin,
    );
    var access = await admin.appAccess
        .fsEntityUserAccessRef('my-app', 'alice')
        .cast<TkCmsEditedFsUserAccess>()
        .get(firestore);
    expect(access.email.v, 'alice@example.com');
    // Listed by name, the email below.
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('alice@example.com · alice'), findsOneWidget);

    // An unknown email is refused.
    await tester.tap(find.text('Add a user'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'nobody@example.com');
    await tester.tap(find.text('Give'));
    await _settle(tester);
    expect(find.text('Bad state: No user nobody@example.com'), findsOneWidget);

    // Made a mere admin, then removed.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await _settle(tester);
    await tester.tap(find.text('admin').last);
    await _settle(tester);
    expect(
      await grantOf(admin.appAccess, 'my-app', 'alice'),
      FestenaoUserAccessGrant.admin,
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await _settle(tester);
    await tester.tap(find.text('Remove the access'));
    await _settle(tester);
    await tester.tap(find.text('Remove'));
    await _settle(tester);
    expect(await grantOf(admin.appAccess, 'my-app', 'alice'), isNull);
    expect(find.text('No user has an access yet'), findsOneWidget);
  });

  _testWidgets('project users and a user across the apps', (tester) async {
    await setUpData();
    await admin.setUserAccess(
      admin.appAccess,
      'my-app',
      'bob',
      grant: FestenaoUserAccessGrant.admin,
      email: 'bob@example.com',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AdminAppScreen(admin: admin, appId: 'my-app', auth: auth),
      ),
    );
    await _settle(tester);
    expect(find.text('1 user: 1 admin'), findsOneWidget);

    // Bob writes in the project.
    await tester.tap(find.text('Project 1'));
    await _settle(tester);
    expect(find.text('Users of Project 1'), findsOneWidget);
    await tester.tap(find.text('Add a user'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'bob');
    await tester.tap(find.text('Give'));
    await _settle(tester);
    expect(
      await grantOf(admin.projectAccess('my-app'), 'p1', 'bob'),
      FestenaoUserAccessGrant.write,
    );

    // Everything Bob has, from the project user list.
    await tester.tap(find.text('Bob'));
    await _settle(tester);
    expect(find.text('bob@example.com'), findsOneWidget);
    // The app access, and the app of the project access.
    expect(find.text('my-app'), findsNWidgets(2));
    expect(find.text('p1'), findsOneWidget);

    // Bob given the ghost app, as a reader.
    await tester.tap(find.text('Give an app access'));
    await _settle(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await _settle(tester);
    await tester.tap(find.text('ghost-app').last);
    await _settle(tester);
    await tester.tap(
      find.byType(DropdownButtonFormField<FestenaoUserAccessGrant>),
    );
    await _settle(tester);
    await tester.tap(find.text('read').last);
    await _settle(tester);
    await tester.tap(find.text('Give'));
    await _settle(tester);
    expect(
      await grantOf(admin.appAccess, 'ghost-app', 'bob'),
      FestenaoUserAccessGrant.read,
    );
    expect(find.text('ghost-app'), findsOneWidget);
  });
}

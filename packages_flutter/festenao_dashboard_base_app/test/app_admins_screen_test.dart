import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/server/festeano_server_entity_handler.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:festenao_common/test/festenao_user_info_test_runner.dart';
import 'package:festenao_dashboard_base_app/screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// The app admins screen through the api of the in memory festenao server
/// (an app entity handler added, as a festenaoprv server has).
void main() {
  late FestenaoTestServerContext context;
  late Firestore firestore;
  late TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsApp> appDb;
  late String app;
  late String ownerId;
  late String addedUserId;
  const addedEmail = 'added.admin@festenao-test.local';
  const invitedEmail = 'invited.admin@festenao-test.local';

  setUpAll(() async {
    context = await initFestenaoTestServerContextAllMemory();
    firestore = context.clientContext.firestore!;
    appDb = context.fsDatabase.appDb;
    app = context.fsDatabase.app;
    var server = context.serverApp!;
    server.moduleApiHandlers.add(
      FestenaoEntityHandler<TkCmsFsApp>(app: server, entityAccess: appDb),
    );
    ownerId = context.clientContext.firebaseAuth!.currentUser!.uid;
    // The app, the owner its super admin (no rules in memory).
    await appDb.fsEntityRef(app).set(firestore, TkCmsFsApp()..name.v = app);
    var ownerRef = appDb
        .fsEntityUserAccessRef(app, ownerId)
        .cast<TkCmsEditedFsUserAccess>();
    await ownerRef.set(
      firestore,
      ownerRef.cv()
        ..grantSuperAdminAccess()
        ..name.v = 'Owner',
    );
    addedUserId = await festenaoLocalAuthCreateUser(
      context,
      email: addedEmail,
      displayName: 'Added Admin',
    );
  });
  tearDownAll(() async {
    await context.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<TkCmsFsUserAccess?> accessOf(
    WidgetTester tester,
    String userId,
  ) async {
    var access = await tester.runAsync(
      () => appDb.fsEntityUserAccessRef(app, userId).get(firestore),
    );
    return access!.exists ? access : null;
  }

  testWidgets('list, add by email, invite, remove', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: festenaoAdminAppAllLocalizationsDelegates,
        supportedLocales: festenaoAdminAppSupportedLocales,
        home: DashboardAppAdminsScreen(
          apiService: context.apiService,
          appEntityAccess: appDb,
          appId: app,
          firestore: firestore,
          userId: ownerId,
        ),
      ),
    );
    await settle(tester);
    var intl = festenaoAdminAppIntl(
      tester.element(find.byType(DashboardAppAdminsScreen)),
    );
    expect(find.text('Owner (${intl.appAdminsYou})'), findsOneWidget);
    expect(find.text(intl.appAdminsNone), findsOneWidget);

    // An account: made an admin right away.
    await tester.tap(find.text(intl.appAdminsAdd));
    await settle(tester);
    // The owner is a super admin: offered.
    expect(find.text(intl.appAdminsSuperAdmin), findsWidgets);
    await tester.enterText(find.byType(TextField), addedEmail);
    await tester.tap(find.text(intl.projectEmailAddNow));
    await settle(tester);
    var access = await accessOf(tester, addedUserId);
    expect(access!.isAdmin, isTrue);
    expect(access.hasSuperAdminRole, isFalse);
    expect(find.text('Added Admin'), findsOneWidget);

    // No account: invited once confirmed.
    await tester.tap(find.text(intl.appAdminsAdd));
    await settle(tester);
    await tester.enterText(find.byType(TextField), invitedEmail);
    await tester.tap(find.text(intl.projectEmailAddNow));
    await settle(tester);
    expect(find.text(intl.projectEmailNoAccount(invitedEmail)), findsOneWidget);
    await tester.tap(
      find.widgetWithText(TextButton, intl.projectEmailInviteSend),
    );
    await settle(tester);
    expect(find.text(invitedEmail), findsOneWidget);
    expect(find.text(intl.appAdminsNone), findsNothing);
    var invites = await tester.runAsync(
      () => FestenaoApiFsEntityClient<TkCmsFsApp>(
        apiService: context.apiService,
        entityAccess: appDb,
      ).listEntityEmailInvites(entityId: app),
    );
    expect(invites!.single.email.v, invitedEmail);
    expect(invites.single.isAdmin, isTrue);

    // The added admin removed.
    await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton).first);
    await settle(tester);
    await tester.tap(find.text(intl.appAdminsRemove).last);
    await settle(tester);
    expect(
      find.text(intl.appAdminsRemoveConfirm('Added Admin')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, intl.appAdminsRemove));
    await settle(tester);
    expect(await accessOf(tester, addedUserId), isNull);
    expect(find.text('Added Admin'), findsNothing);
  });
}

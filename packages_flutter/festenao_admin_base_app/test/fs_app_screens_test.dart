import 'package:festenao_admin_base_app/auth/app_auth_bloc.dart';
import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_admin_base_app/screen/fs_app_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/fs_app_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/fs_app_project_view_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/fs_app_view_screen.dart';
import 'package:festenao_admin_base_app/view/app_identity_info_tile.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

const _timeout = Timeout(Duration(minutes: 2));

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: festenaoAdminAppAllLocalizationsDelegates,
  supportedLocales: festenaoAdminAppSupportedLocales,
  home: home,
);

/// Pumps (bounded) until [finder] finds something, letting the memory
/// firestore run.
Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}

/// Pumps a few frames, letting the memory firestore run.
Future<void> _pumpSome(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FestenaoFirestoreDatabase fsDatabase;
  late String userId;

  setUpAll(() async {
    // The debug path bar needs the pages of the app router.
    festenaoAdminAppShowPathBar = false;
    initTkCmsFsUserAccessBuilders();
    var ffContext = await initFirebaseServicesLocalMemory(
      projectId: 'fs-app-screens-test',
    ).init();
    fsDatabase = FestenaoFirestoreDatabase(
      firebaseContext: ffContext,
      flavorContext: AppFlavorContext.test,
    );
    globalFestenaoFirestoreDatabaseOrNull = fsDatabase;
    globalTkCmsFbIdentityBloc = TkCmsFbIdentityBloc(auth: ffContext.auth);
    await ffContext.auth.signInOrUpWithEmailAndPassword(
      email: 'u1',
      password: 'u1',
    );
    await globalTkCmsFbIdentityBloc.state.firstWhere(
      (state) => state.identity != null,
    );
    userId = ffContext.auth.currentUser!.uid;
    await fsDatabase.appDb
        .fsEntityRef('a1')
        .set(fsDatabase.firestore, TkCmsFsApp()..name.v = 'Before');
  });

  test('creating an app with an existing id fails', () async {
    await fsDatabase.appDb
        .fsEntityRef('a_existing')
        .set(
          fsDatabase.firestore,
          TkCmsFsApp()
            ..name.v = 'Existing'
            ..active.v = true,
        );
    var bloc = FsAppEditScreenBloc(param: FsAppEditScreenParam(appId: null));
    addTearDown(bloc.dispose);
    await bloc.state.first;
    await expectLater(
      bloc.saveApp(
        FsAppEditData(appId: 'a_existing', app: TkCmsFsApp()..name.v = 'Other'),
      ),
      throwsA(isA<StateError>()),
    );
    var app = await fsDatabase.appDb
        .fsEntityRef('a_existing')
        .get(fsDatabase.firestore);
    expect(app.name.v, 'Existing');
    expect(app.active.v, isTrue);
    // A new id is created.
    await bloc.saveApp(
      FsAppEditData(appId: 'a_new', app: TkCmsFsApp()..name.v = 'New'),
    );
    expect(
      (await fsDatabase.appDb.fsEntityRef('a_new').get(fsDatabase.firestore))
          .name
          .v,
      'New',
    );
  }, timeout: _timeout);

  testWidgets('the app identity tile without an app auth bloc', (tester) async {
    globalFestenaoAppAuthBlocOrNull = null;
    await tester.pumpWidget(_app(const Scaffold(body: AppIdentityInfoTile())));
    await _pumpSome(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(userId), findsOneWidget);
  }, timeout: _timeout);

  testWidgets('editing an app name then back asks to save', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => goToFsAppEditScreen(context, appId: 'a1'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _pumpUntil(tester, find.text('Before'));
    expect(find.text('Before'), findsOneWidget);
    await tester.enterText(find.text('Before'), 'After');
    await tester.pump();
    var intl = festenaoAdminAppIntl(tester.element(find.byType(Scaffold)));
    await tester.binding.handlePopRoute();
    await _pumpSome(tester);
    expect(find.text(intl.editUnsavedChangesTitle), findsOneWidget);
  }, timeout: _timeout);

  testWidgets('back from an edited app reports the modification', (
    tester,
  ) async {
    // The app identity tile of the view reads it.
    globalFestenaoAppAuthBlocOrNull = AppAuthBloc(fsDatabase.fsApp);
    FsAppViewResult? viewResult;
    var closed = false;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              viewResult = await goToFsAppViewScreen(context, appId: 'a1');
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _pumpUntil(tester, find.byIcon(Icons.edit));
    // The route transitions done.
    await _pumpSome(tester);
    await tester.tap(find.byIcon(Icons.edit));
    await _pumpUntil(tester, find.byType(TextFormField));
    await _pumpSome(tester);
    await tester.enterText(find.byType(TextFormField).last, 'Edited');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.save));
    await _pumpUntil(tester, find.byIcon(Icons.edit));
    expect(find.byIcon(Icons.edit), findsOneWidget);
    // Back from the app view.
    await tester.binding.handlePopRoute();
    await _pumpSome(tester);
    expect(closed, isTrue);
    expect(viewResult?.modified, isTrue);
  }, timeout: _timeout);

  test('app admin rights come from the app viewed', () async {
    // Admin of the default app only.
    await fsDatabase.appDb.setEntityUserAccess(
      entityId: fsDatabase.appId,
      userId: userId,
      userAccess: TkCmsFsUserAccess.admin(),
    );
    globalFestenaoAppAuthBlocOrNull = AppAuthBloc(fsDatabase.fsApp);
    await globalFestenaoAppAuthBloc.state.firstWhere(
      (state) => state.userAccess?.isAdmin ?? false,
    );

    Future<FsAppProjectViewScreenBlocState> lastState(String appId) async {
      var bloc = FsAppProjectViewScreenBloc(projectId: 'p1', appId: appId);
      addTearDown(bloc.dispose);
      await bloc.state.firstWhere((state) => state.identity != null);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return bloc.state.value;
    }

    expect((await lastState(fsDatabase.appId)).isAppAdmin, isTrue);
    expect((await lastState('other_app')).isAppAdmin, isFalse);
  }, timeout: _timeout);
}

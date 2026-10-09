import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';
import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:festenao_common/test/festenao_user_info_test_runner.dart';
import 'package:festenao_dashboard_base_app/screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// The dashboard user edit screen filling a user from its account, through
/// the get-user-info command of the in memory festenao server.
void main() {
  late FestenaoTestServerContext context;
  late String entityId;
  late String memberUserId;
  late String strangerUserId;

  AdminProjectUserEditScreenBloc newBloc(String? userId, {bool api = true}) =>
      AdminProjectUserEditScreenBloc(
        param: AdminProjectUserEditScreenParam(
          projectId: entityId,
          userId: userId,
        ),
        entityAccess: context.fsDatabase.projectDb,
        apiService: api ? context.apiService : null,
      );

  setUpAll(() async {
    context = await initFestenaoTestServerContextAllMemory();
    entityId = (await context.projectApiClient.createEntity(
      entity: FsProject()..name.v = 'Fill test',
    )).id;
    memberUserId = await festenaoLocalAuthCreateUser(
      context,
      email: 'camille.fill@festenao-test.local',
      displayName: 'Camille Martin',
      emailVerified: true,
    );
    strangerUserId = await festenaoLocalAuthCreateUser(
      context,
      email: 'ines.fill@festenao-test.local',
      displayName: 'Inès Dubois',
    );
    // The member reads the project, with no name nor email in its access
    // (written on the server side, as an admin would).
    var memberAccessRef = context.fsDatabase.projectDb.fsEntityUserAccessRef(
      entityId,
      memberUserId,
    );
    await memberAccessRef.set(
      context.ffContext.firestore,
      memberAccessRef.cv()
        ..read.v = true
        ..fixAccess(),
    );
  });
  tearDownAll(() async {
    await context.close();
  });

  group('bloc', () {
    test('no api service, no reader', () {
      expect(globalFestenaoApiServiceOrNull, isNull);
      var bloc = newBloc(memberUserId, api: false);
      expect(bloc.userInfoSupported, isFalse);
      expect(bloc.userInfoReader, isNull);
      bloc.dispose();
    });

    test('the project admin reads a member', () async {
      var bloc = newBloc(memberUserId);
      expect(bloc.userInfoSupported, isTrue);
      var info = await bloc.userInfoReader!(memberUserId);
      expect(info.name, 'Camille Martin');
      expect(info.email, 'camille.fill@festenao-test.local');
      bloc.dispose();
    });

    test('but not a user without access', () async {
      var bloc = newBloc(null);
      var name = TextEditingController(text: 'typed');
      var email = TextEditingController();
      var error = await festenaoFillUserFromAccount(
        reader: bloc.userInfoReader!,
        userId: strangerUserId,
        nameController: name,
        emailController: email,
      );
      expect(error?.code, festenaoFillUserErrorPermissionDenied);
      expect(name.text, 'typed');
      expect(email.text, isEmpty);
      bloc.dispose();
    });
  });

  group('screen', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<AdminProjectUserEditScreenBloc> pumpScreen(
      WidgetTester tester,
      String? userId,
    ) async {
      var bloc = newBloc(userId);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: festenaoAdminAppAllLocalizationsDelegates,
          supportedLocales: festenaoAdminAppSupportedLocales,
          home: BlocProvider<AdminProjectUserEditScreenBloc>(
            blocBuilder: () => bloc,
            child: const ProjectSdbUserEditScreen(),
          ),
        ),
      );
      await settle(tester);
      return bloc;
    }

    String fieldText(WidgetTester tester, String label) => tester
        .widget<TextField>(
          find.descendant(
            of: find.widgetWithText(TextFormField, label),
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;

    testWidgets('an existing member is filled when it opens', (tester) async {
      await pumpScreen(tester, memberUserId);
      expect(find.text('Remplir depuis le compte'), findsOneWidget);
      var intl = festenaoAdminAppIntl(
        tester.element(find.byType(ProjectSdbUserEditScreen)),
      );
      expect(fieldText(tester, intl.nameLabel), 'Camille Martin');
      expect(
        fieldText(tester, intl.emailLabel),
        'camille.fill@festenao-test.local',
      );
    });

    testWidgets('the button reports a refusal', (tester) async {
      await pumpScreen(tester, null);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'User ID'),
        strangerUserId,
      );
      await tester.tap(find.text('Remplir depuis le compte'));
      await settle(tester);
      expect(find.text('Vous ne pouvez pas lire ce compte'), findsOneWidget);
    });
  });
}

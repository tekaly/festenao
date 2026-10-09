import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen.dart';
import 'package:festenao_admin_base_app/view/access_view.dart';
import 'package:festenao_theme/design.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';

TkCmsEditedFsUserAccess _access(
  String id, {
  String? name,
  String? email,
  AdminAccessRole role = AdminAccessRole.reader,
}) {
  var flags = role.flags;
  return CvDocumentReference<TkCmsEditedFsUserAccess>('user_access/$id').cv()
    ..name.setValue(name)
    ..email.setValue(email)
    ..admin.v = flags.admin
    ..write.v = flags.write
    ..read.v = flags.read;
}

Widget _app(Widget home) => MaterialApp(
  theme: festenaoThemeFestenao.themeData(Brightness.light),
  localizationsDelegates: festenaoAdminAppAllLocalizationsDelegates,
  supportedLocales: festenaoAdminAppSupportedLocales,
  home: home,
);

/// The edit form alone.
class _Form extends StatefulWidget {
  const _Form();

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends AutoDisposeBaseState<_Form>
    with AdminUserEditScreenMixin {
  @override
  void initState() {
    super.initState();
    initControllers(
      userId: 'camille',
      user: _access('camille', role: AdminAccessRole.none),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Form(child: ListView(children: [buildDataWidget(context)])),
  );
}

void main() {
  // Before the groups: the test data is built while they are defined.
  initTkCmsFsUserAccessBuilders();
  cvAddConstructor(TkCmsEditedFsUserAccess.new);

  group('role', () {
    test('from the flags and back', () {
      for (var role in AdminAccessRole.values) {
        var flags = role.flags;
        expect(
          AdminAccessRole.ofFlags(
            admin: flags.admin,
            write: flags.write,
            read: flags.read,
          ),
          role,
        );
        expect(AdminAccessRole.of(_access('u', role: role)), role);
      }
      // Admin includes write and read.
      expect(AdminAccessRole.admin.flags, (
        read: true,
        write: true,
        admin: true,
      ));
      expect(AdminAccessRole.reader.flags, (
        read: true,
        write: false,
        admin: false,
      ));
    });

    test('display name and detail', () {
      var named = _access('u1', name: 'Camille Martin', email: 'c@test.local');
      expect(adminAccessDisplayName(named), 'Camille Martin');
      expect(adminAccessDisplayDetail(named), 'c@test.local');
      var emailOnly = _access('u2', email: 'hugo@test.local');
      expect(adminAccessDisplayName(emailOnly), 'hugo@test.local');
      expect(adminAccessDisplayDetail(emailOnly), 'u2');
      var idOnly = _access('u3');
      expect(adminAccessDisplayName(idOnly), 'u3');
      expect(adminAccessDisplayDetail(idOnly), isNull);
    });
  });

  group('members view', () {
    var users = [
      _access(
        'ines',
        name: 'Inès Dubois',
        email: 'ines@test.local',
        role: AdminAccessRole.admin,
      ),
      _access('alex', name: 'Alex Martin', role: AdminAccessRole.admin),
      _access(
        'camille',
        name: 'Camille Roux',
        email: 'camille@test.local',
        role: AdminAccessRole.editor,
      ),
      _access('hugo', email: 'hugo@test.local'),
      _access('-P3R0_OkzQ3rNhDvd454'),
    ];

    testWidgets('people by name, roles, you, search', (tester) async {
      String? tapped;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: AdminAccessMembersView(
              users: users,
              subtitle: 'Who can open and edit this project',
              currentUserId: 'ines',
              onTap: (access) => tapped = access.id,
            ),
          ),
        ),
      );
      expect(find.text('Members · 5'), findsOneWidget);
      // Names, not ids; the email under the name.
      expect(find.text('Inès Dubois'), findsOneWidget);
      expect(find.text('ines@test.local'), findsOneWidget);
      expect(find.text('hugo@test.local'), findsOneWidget);
      // Sorted by name.
      expect(
        tester.getTopLeft(find.text('Alex Martin')).dy,
        lessThan(tester.getTopLeft(find.text('Camille Roux')).dy),
      );
      expect(find.text('Admin'), findsNWidgets(2));
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('Reader'), findsNWidgets(2));
      expect(find.text('you'), findsOneWidget);

      await tester.tap(find.text('Camille Roux'));
      expect(tapped, 'camille');

      // The search filters by name, email or id.
      await tester.enterText(find.byType(TextField), 'HUGO');
      await tester.pump();
      expect(find.text('hugo@test.local'), findsOneWidget);
      expect(find.text('Inès Dubois'), findsNothing);
      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.pump();
      expect(find.text('No user matches'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no user yet', (tester) async {
      await tester.pumpWidget(
        _app(const Scaffold(body: AdminAccessMembersView(users: []))),
      );
      expect(find.text('No user yet'), findsOneWidget);
      // No search below four users.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a phone width fits', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(Scaffold(body: AdminAccessMembersView(users: users))),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the edit form sets one role', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(const _Form()));
    var state = tester.state<_FormState>(find.byType(_Form));
    // No access yet: the warning.
    expect(find.text('No access: pick a role'), findsOneWidget);

    await tester.tap(find.text('Editor'));
    await tester.pumpAndSettle();
    expect(
      (state.read.value, state.write.value, state.admin.value),
      (true, true, false),
    );
    expect(find.text('Edits the content'), findsOneWidget);

    await tester.tap(find.text('Admin'));
    await tester.pumpAndSettle();
    expect(
      (state.read.value, state.write.value, state.admin.value),
      (true, true, true),
    );

    await tester.tap(find.text('Reader'));
    await tester.pumpAndSettle();
    expect(
      (state.read.value, state.write.value, state.admin.value),
      (true, false, false),
    );
    expect(state.getEditedUser().isRead, isTrue);
    expect(state.getEditedUser().isWrite, isFalse);
  });
}

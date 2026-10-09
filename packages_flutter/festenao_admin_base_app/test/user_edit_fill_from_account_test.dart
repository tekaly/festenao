import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tkcms_common/tkcms_api.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';

typedef _Reader = Future<({String? name, String? email})> Function(
  String userId,
);

/// The user edit form alone, with a fake account reader.
class _Form extends StatefulWidget {
  final _Reader? reader;
  final TkCmsEditedFsUserAccess? user;

  const _Form({this.reader, this.user});

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends AutoDisposeBaseState<_Form>
    with AdminUserEditScreenMixin {
  @override
  _Reader? get userInfoReader => widget.reader;

  @override
  void initState() {
    super.initState();
    initControllers(userId: 'camille', user: widget.user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(child: ListView(children: [buildDataWidget(context)])),
    );
  }
}

Future<_FormState> _pump(
  WidgetTester tester, {
  _Reader? reader,
  TkCmsEditedFsUserAccess? user,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: festenaoAdminAppAllLocalizationsDelegates,
      supportedLocales: festenaoAdminAppSupportedLocales,
      home: _Form(reader: reader, user: user),
    ),
  );
  await tester.pumpAndSettle();
  return tester.state<_FormState>(find.byType(_Form));
}

void main() {
  testWidgets('no reader, no fill button', (tester) async {
    await _pump(tester);
    expect(find.text('Fill from the account'), findsNothing);
  });

  testWidgets('the button fills the name and the email', (tester) async {
    var asked = <String>[];
    var state = await _pump(
      tester,
      reader: (userId) async {
        asked.add(userId);
        return (name: 'Camille Martin', email: 'camille@test.local');
      },
      user: TkCmsEditedFsUserAccess()..name.v = 'Old name',
    );
    await tester.tap(find.text('Fill from the account'));
    await tester.pumpAndSettle();
    expect(asked, ['camille']);
    expect(state.nameController.text, 'Camille Martin');
    expect(state.emailController.text, 'camille@test.local');
  });

  testWidgets('the automatic fill keeps what is typed', (tester) async {
    var state = await _pump(
      tester,
      reader: (userId) async =>
          (name: 'Camille Martin', email: 'camille@test.local'),
      user: TkCmsEditedFsUserAccess()..name.v = 'Camille (cuisine)',
    );
    await state.fillFromAccount(
      tester.element(find.byType(_Form)),
      onlyEmpty: true,
      quiet: true,
    );
    await tester.pumpAndSettle();
    expect(state.nameController.text, 'Camille (cuisine)');
    expect(state.emailController.text, 'camille@test.local');
  });

  testWidgets('a refusal is reported, nothing changes', (tester) async {
    var state = await _pump(
      tester,
      reader: (userId) async =>
          throw (ApiError()
                ..code.v = 'permission-denied'
                ..message.v = 'Not allowed')
              .exception(),
      user: TkCmsEditedFsUserAccess()..email.v = 'kept@test.local',
    );
    await tester.tap(find.text('Fill from the account'));
    await tester.pumpAndSettle();
    expect(find.text('Not allowed to read this account'), findsOneWidget);
    expect(state.emailController.text, 'kept@test.local');
  });

  testWidgets('an unknown user is reported', (tester) async {
    await _pump(
      tester,
      reader: (userId) async =>
          throw (ApiError()
                ..code.v = 'not-found'
                ..message.v = 'User not found')
              .exception(),
    );
    await tester.tap(find.text('Fill from the account'));
    await tester.pumpAndSettle();
    expect(find.text('Unknown account: camille'), findsOneWidget);
  });
}

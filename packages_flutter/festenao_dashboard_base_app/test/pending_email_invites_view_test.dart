import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:festenao_dashboard_base_app/screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// A notifier with a fixed state, recording what is accepted and declined.
class _FakeNotifier extends RpdPendingEmailInvites {
  final PendingEmailInvitesState initial;
  final accepted = <String>[];
  final declined = <String>[];

  _FakeNotifier(this.initial);

  @override
  Future<PendingEmailInvitesState> build() async => initial;

  @override
  Future<void> accept(TkCmsCvEmailInvite invite) async {
    accepted.add(invite.inviteId.v!);
    state = AsyncData(state.value!.without(invite));
  }

  @override
  Future<void> discard(TkCmsCvEmailInvite invite) async {
    declined.add(invite.inviteId.v!);
    state = AsyncData(state.value!.without(invite));
  }
}

TkCmsCvEmailInvite _invite(
  String id,
  String entityName, {
  bool write = false,
}) => TkCmsCvEmailInvite()
  ..inviteId.v = id
  ..entityId.v = 'entity_$id'
  ..entityName.v = entityName
  ..email.v = 'me@test.local'
  ..status.v = tkCmsEmailInviteStatusPending
  ..read.v = true
  ..write.v = write
  ..admin.v = false;

Future<_FakeNotifier> _pump(
  WidgetTester tester,
  PendingEmailInvitesState state,
) async {
  var notifier = _FakeNotifier(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [rpdPendingEmailInvitesProvider.overrideWith(() => notifier)],
      child: const MaterialApp(
        localizationsDelegates: festenaoAdminAppAllLocalizationsDelegates,
        supportedLocales: festenaoAdminAppSupportedLocales,
        home: Scaffold(body: PendingEmailInvitesView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  testWidgets('nothing without an invite', (tester) async {
    await _pump(tester, const PendingEmailInvitesState());
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('lists the invites, accept and decline', (tester) async {
    var notifier = await _pump(
      tester,
      PendingEmailInvitesState(
        email: 'me@test.local',
        emailVerified: true,
        invites: [
          _invite('i1', 'Project one', write: true),
          _invite('i2', 'Project two'),
        ],
      ),
    );
    expect(find.text('Invitations'), findsOneWidget);
    expect(find.text('For me@test.local'), findsOneWidget);
    expect(find.text('Project one'), findsOneWidget);
    expect(find.text('Project two'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Accept'), findsNWidgets(2));

    // Accept the first one, after the confirmation.
    await tester.tap(find.widgetWithText(FilledButton, 'Accept').first);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Project one'), findsNWidgets(2));
    // The dialog title repeats the action: tap its button.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Accept'),
      ),
    );
    await tester.pumpAndSettle();
    expect(notifier.accepted, ['i1']);
    expect(find.text('Project one'), findsNothing);
    expect(find.text('Project two'), findsOneWidget);

    // Cancel a decline: nothing happens.
    await tester.tap(find.widgetWithText(TextButton, 'Decline'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(notifier.declined, isEmpty);
    expect(find.text('Project two'), findsOneWidget);

    // Decline it: the card goes away with the last invite.
    await tester.tap(find.widgetWithText(TextButton, 'Decline'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Decline'),
      ),
    );
    await tester.pumpAndSettle();
    expect(notifier.declined, ['i2']);
    expect(find.byType(Card), findsNothing);
    // Let the snack bars go away before the end.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}

import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/view/access_view.dart';
import 'package:festenao_dashboard_base_app/src/provider/email_invite_providers.dart';
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// The pending email invites of the signed in user, to put at the top of a
/// screen (the home page, the projects list): a card with a line per invite
/// (the project, the role given, accept and decline), nothing at all when
/// there is none, when signed out or when the app has no api service for
/// them.
///
/// Watching it is what triggers the check, on the app start and after each
/// sign in (see [rpdPendingEmailInvitesProvider]).
class PendingEmailInvitesView extends ConsumerStatefulWidget {
  /// The pending email invites view.
  const PendingEmailInvitesView({super.key});

  @override
  ConsumerState<PendingEmailInvitesView> createState() =>
      _PendingEmailInvitesViewState();
}

class _PendingEmailInvitesViewState
    extends ConsumerState<PendingEmailInvitesView> {
  bool _busy = false;

  String _entityLabel(TkCmsCvEmailInvite invite) =>
      invite.entityName.v ?? invite.entityId.v ?? '';

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    Color? actionColor,
  }) async {
    var intl = festenaoAdminAppIntl(context);
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(intl.cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: actionColor == null
                ? null
                : TextButton.styleFrom(foregroundColor: actionColor),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
    String doneMessage,
  ) async {
    setState(() => _busy = true);
    try {
      await action();
      if (context.mounted) {
        await muiSnack(context, doneMessage);
      }
    } catch (e) {
      if (context.mounted) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('email invite error: $e');
        }
        await muiSnack(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _accept(BuildContext context, TkCmsCvEmailInvite invite) async {
    var intl = festenaoAdminAppIntl(context);
    if (!await _confirm(
      context,
      title: intl.pendingEmailInviteAccept,
      message: intl.pendingEmailInviteAcceptConfirm(_entityLabel(invite)),
      action: intl.pendingEmailInviteAccept,
    )) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _run(
      context,
      () => ref.read(rpdPendingEmailInvitesProvider.notifier).accept(invite),
      intl.pendingEmailInviteAccepted,
    );
  }

  Future<void> _decline(BuildContext context, TkCmsCvEmailInvite invite) async {
    var intl = festenaoAdminAppIntl(context);
    if (!await _confirm(
      context,
      title: intl.pendingEmailInviteDecline,
      message: intl.pendingEmailInviteDeclineConfirm(_entityLabel(invite)),
      action: intl.pendingEmailInviteDecline,
      actionColor: context.festenao.bad,
    )) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _run(
      context,
      () => ref.read(rpdPendingEmailInvitesProvider.notifier).discard(invite),
      intl.pendingEmailInviteDeclined,
    );
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    var state = ref.watch(rpdPendingEmailInvitesProvider).value;
    if (state == null || state.isEmpty) {
      return const SizedBox.shrink();
    }
    var email = state.email;
    return Padding(
      padding: const EdgeInsets.only(bottom: FestenaoSpace.xl),
      child: FkCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const FkIconBox(Icons.mail_outline),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          intl.pendingEmailInvitesTitle,
                          style: text.titleSmall,
                        ),
                        if (email != null)
                          Text(
                            intl.pendingEmailInviteFor(email),
                            style: text.bodySmall?.copyWith(color: t.ink2),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (var invite in state.invites) ...[
              Divider(color: t.line),
              _InviteLine(
                invite: invite,
                label: _entityLabel(invite),
                busy: _busy,
                onAccept: () => _accept(context, invite),
                onDecline: () => _decline(context, invite),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One invite: the project and the role given, the decline and accept
/// buttons (under them on a narrow card).
class _InviteLine extends StatelessWidget {
  final TkCmsCvEmailInvite invite;
  final String label;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InviteLine({
    required this.invite,
    required this.label,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var text = Theme.of(context).textTheme;
    var role = AdminAccessRole.of(invite);
    var titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [FkStatusPill(role.label(intl), status: role.status)],
        ),
      ],
    );
    var buttons = Wrap(
      spacing: 8,
      children: [
        TextButton(
          onPressed: busy ? null : onDecline,
          child: Text(intl.pendingEmailInviteDecline),
        ),
        FilledButton(
          onPressed: busy ? null : onAccept,
          child: Text(intl.pendingEmailInviteAccept),
        ),
      ],
    );
    // A wrap rather than a layout builder: the home page measures this view
    // (a sliver filling the rest of the page), which a layout builder cannot.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [titles, buttons],
      ),
    );
  }
}

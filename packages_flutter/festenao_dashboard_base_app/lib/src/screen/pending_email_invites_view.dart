import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/utils/project_ui_utils.dart';
import 'package:festenao_dashboard_base_app/src/provider/email_invite_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// The pending email invites of the signed in user, to put at the top of a
/// screen (the home page, the projects list): one line per invite with accept
/// and decline, nothing at all when there is none, when signed out or when
/// the app has no api service for them.
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
        await muiSnack(context, 'Erreur: $e');
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
      actionColor: Colors.red,
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
    var state = ref.watch(rpdPendingEmailInvitesProvider).value;
    if (state == null || state.isEmpty) {
      return const SizedBox.shrink();
    }
    var email = state.email;
    return BodyContainer(
      child: Card(
        margin: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(intl.pendingEmailInvitesTitle),
              subtitle: email == null
                  ? null
                  : Text(intl.pendingEmailInviteFor(email)),
            ),
            for (var invite in state.invites)
              ListTile(
                title: Text(_entityLabel(invite)),
                subtitle: Text(accessString(intl, invite)),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : () => _decline(context, invite),
                      child: Text(intl.pendingEmailInviteDecline),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : () => _accept(context, invite),
                      child: Text(intl.pendingEmailInviteAccept),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

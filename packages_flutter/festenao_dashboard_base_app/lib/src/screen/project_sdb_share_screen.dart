import 'package:barcode_widget/barcode_widget.dart';
import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/view/access_view.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_invite_view_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_share_screen_bloc.dart';
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Project share screen, on the festenao kit: the role an invite gives, an
/// invite link (with its qr code), and the invites by email (addressed
/// invites, for an admin, when the secured api is there).
///
/// Dashboard counterpart of Notelio's `BookletShareScreen`.
class ProjectSdbShareScreen extends StatefulWidget {
  const ProjectSdbShareScreen({super.key});

  @override
  State<ProjectSdbShareScreen> createState() => _ProjectSdbShareScreenState();
}

class _ProjectSdbShareScreenState
    extends AutoDisposeBaseState<ProjectSdbShareScreen> {
  /// The role the next invite (link or email) gives.
  var _role = AdminAccessRole.reader;

  /// The role of the signed in user, the highest it can give.
  var _ownRole = AdminAccessRole.reader;
  bool _busy = false;
  bool _accessInitialized = false;
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _initAccess(SdbSharedEntity project) {
    _accessInitialized = true;
    _ownRole = AdminAccessRole.ofFlags(
      admin: project.isAdmin,
      write: project.isWrite,
      read: project.isRead,
    );
    _role = _ownRole == AdminAccessRole.none
        ? AdminAccessRole.reader
        : _ownRole;
  }

  Future<void> _share(
    BuildContext context,
    ProjectSdbShareScreenBloc bloc,
  ) async {
    setState(() => _busy = true);
    var flags = _role.flags;
    try {
      await bloc.createInvite(
        admin: flags.admin,
        write: flags.write,
        read: flags.read,
      );
    } catch (e) {
      if (context.mounted) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('share error: $e');
        }
        await muiSnack(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String content,
    required String action,
  }) async {
    var intl = festenaoAdminAppIntl(context);
    var t = context.festenao;
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(intl.cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: t.bad),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteInvite(
    BuildContext context,
    ProjectSdbShareScreenBloc bloc,
    String inviteId,
  ) async {
    var intl = festenaoAdminAppIntl(context);
    if (await _confirm(
      context,
      title: intl.projectInviteDelete,
      content: intl.projectInviteDeleteConfirm,
      action: intl.deleteButtonLabel,
    )) {
      setState(() => _busy = true);
      try {
        await bloc.deleteInvite(inviteId);
      } finally {
        if (mounted) {
          setState(() => _busy = false);
        }
      }
    }
  }

  Future<void> _copy(BuildContext context, String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      await muiSnack(context, message);
    }
  }

  Future<void> _sendEmailInvite(
    BuildContext context,
    ProjectSdbShareScreenBloc bloc,
  ) async {
    var intl = festenaoAdminAppIntl(context);
    var email = tkCmsNormalizeInviteEmail(_emailController.text);
    if (email == null || !email.contains('@')) {
      await muiSnack(context, intl.projectEmailInviteInvalidEmail);
      return;
    }
    setState(() => _busy = true);
    var flags = _role.flags;
    try {
      var result = await bloc.createEmailInvite(
        email: email,
        admin: flags.admin,
        write: flags.write,
        read: flags.read,
      );
      _emailController.clear();
      if (context.mounted) {
        // The mail went, or the app sends none: the invitee then finds the
        // invite in the app once signed in with that address.
        await muiSnack(
          context,
          result.mailSent.v == true
              ? intl.projectEmailInviteSent(email)
              : intl.projectEmailInviteSaved(email),
        );
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

  Future<void> _revokeEmailInvite(
    BuildContext context,
    ProjectSdbShareScreenBloc bloc,
    TkCmsCvEmailInvite invite,
  ) async {
    var intl = festenaoAdminAppIntl(context);
    if (await _confirm(
      context,
      title: intl.projectEmailInviteRevoke,
      content: intl.projectEmailInviteRevokeConfirm(invite.email.v ?? ''),
      action: intl.projectEmailInviteRevoke,
    )) {
      setState(() => _busy = true);
      try {
        await bloc.deleteEmailInvite(invite.inviteId.v!);
      } catch (e) {
        if (context.mounted) {
          await muiSnack(context, 'Error: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _busy = false);
        }
      }
    }
  }

  String _emailInviteStatusLabel(AppLocalizations intl, String? status) =>
      switch (status) {
        tkCmsEmailInviteStatusAccepted => intl.projectEmailInviteStatusAccepted,
        tkCmsEmailInviteStatusDiscarded =>
          intl.projectEmailInviteStatusDiscarded,
        _ => intl.projectEmailInviteStatusPending,
      };

  IconData _emailInviteStatusIcon(String? status) => switch (status) {
    tkCmsEmailInviteStatusAccepted => Icons.check_circle_outline,
    tkCmsEmailInviteStatusDiscarded => Icons.cancel_outlined,
    _ => Icons.hourglass_empty,
  };

  Color _emailInviteStatusColor(FestenaoTokens t, String? status) =>
      switch (status) {
        tkCmsEmailInviteStatusAccepted => t.ok,
        tkCmsEmailInviteStatusDiscarded => t.muted,
        _ => t.warn,
      };

  /// The role section: the role the next invite gives, among the ones the
  /// signed in user can give.
  Widget _buildRole(BuildContext context, AppLocalizations intl) {
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    return FkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            intl.projectInviteRoleInformation,
            style: text.bodyMedium?.copyWith(color: t.ink2),
          ),
          const SizedBox(height: 12),
          SegmentedButton<AdminAccessRole>(
            showSelectedIcon: false,
            segments: [
              for (var choice in AdminAccessRole.assignable)
                if (choice.index <= _ownRole.index)
                  ButtonSegment(value: choice, label: Text(choice.label(intl))),
            ],
            selected: {_role},
            onSelectionChanged: _busy
                ? null
                : (selection) => setState(() => _role = selection.first),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: t.ink3),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _role.detail(intl),
                  style: text.bodySmall?.copyWith(color: t.ink2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The invite link section: the button creating it, or the link created
  /// with its qr code and actions.
  Widget _buildLink(
    BuildContext context,
    AppLocalizations intl,
    ProjectSdbShareScreenBloc bloc,
    ProjectSdbShareScreenBlocState state,
  ) {
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    if (!state.canViewInvite) {
      var canShare = !_busy && state.canEditSharing;
      return FkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              intl.projectInviteLinkInformation,
              style: text.bodyMedium?.copyWith(color: t.ink2),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: canShare ? () => _share(context, bloc) : null,
              icon: const Icon(Icons.link),
              label: Text(intl.projectInviteGenerate),
            ),
          ],
        ),
      );
    }
    var inviteId = state.inviteId!;
    var link = ProjectSdbInviteViewScreen.inviteLink(bloc.projectId, inviteId);
    var access = state.invite?.userAccess.v;
    var role = access == null ? null : AdminAccessRole.of(access);
    return FkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            intl.projectInviteLinkInformation,
            style: text.bodyMedium?.copyWith(color: t.ink2),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              color: t.sunk,
              borderRadius: BorderRadius.circular(t.radii.control),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    link,
                    style: text.bodySmall?.copyWith(fontFamily: t.monoFamily),
                  ),
                ),
                IconButton(
                  tooltip: intl.copyButtonLabel,
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _copy(context, link, intl.linkCopied),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (role != null)
                FkStatusPill(role.label(intl), status: role.status),
              Text(
                '${intl.projectInviteIdLabel}: $inviteId',
                style: text.bodySmall?.copyWith(
                  color: t.ink3,
                  fontFamily: t.monoFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 240,
              height: 240,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(t.radii.control),
                border: Border.all(color: t.line),
              ),
              child: BarcodeWidget(
                barcode: Barcode.qrCode(
                  errorCorrectLevel: BarcodeQRCorrectionLevel.high,
                ),
                data: link,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _copy(context, link, intl.linkCopied),
                icon: const Icon(Icons.copy),
                label: Text(intl.copyButtonLabel),
              ),
              if (kDebugMode)
                OutlinedButton.icon(
                  onPressed: () => goToProjectSdbInviteViewScreen(
                    context,
                    projectId: bloc.projectId,
                    inviteId: inviteId,
                    entityAccess: bloc.entityAccess,
                    projectsDb: bloc.projectsDb,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('[debug] Open the invite'),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: t.bad),
                onPressed: _busy
                    ? null
                    : () => _deleteInvite(context, bloc, inviteId),
                icon: const Icon(Icons.delete_outline),
                label: Text(intl.projectInviteDelete),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The email invites: an admin sends addressed invites and sees what
  /// happened to the ones sent (request and response, nothing streams: no
  /// client reads this data).
  List<Widget> _buildEmailInvites(
    BuildContext context,
    AppLocalizations intl,
    ProjectSdbShareScreenBloc bloc,
    ProjectSdbShareScreenBlocState state,
  ) {
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    var emailInvites = state.emailInvites;
    var error = state.emailInvitesError;
    var canSend = !_busy;
    return [
      const SizedBox(height: FestenaoSpace.xl),
      FkSectionTitle(intl.projectEmailInviteTitle),
      FkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              intl.projectEmailInviteInformation,
              style: text.bodyMedium?.copyWith(color: t.ink2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: intl.projectEmailInviteEmailLabel,
                prefixIcon: const Icon(Icons.alternate_email),
              ),
              onSubmitted: canSend
                  ? (_) => _sendEmailInvite(context, bloc)
                  : null,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: canSend ? () => _sendEmailInvite(context, bloc) : null,
              icon: const Icon(Icons.send_outlined),
              label: Text(intl.projectEmailInviteSend),
            ),
          ],
        ),
      ),
      const SizedBox(height: FestenaoSpace.xl),
      FkSectionTitle(intl.projectEmailInviteListTitle),
      if (error != null)
        FkCard(
          child: FkEmpty(icon: Icons.error_outline, message: 'Error: $error'),
        )
      else if (emailInvites == null)
        const FkCard(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
        )
      else if (emailInvites.isEmpty)
        FkCard(
          child: FkEmpty(
            icon: Icons.mail_outline,
            message: intl.projectEmailInviteNone,
          ),
        )
      else
        FkListCard(
          children: [
            for (var invite in emailInvites)
              FkRow(
                leading: FkIconBox(
                  _emailInviteStatusIcon(invite.status.v),
                  color: _emailInviteStatusColor(t, invite.status.v),
                ),
                title: invite.email.v ?? '',
                subtitle: _emailInviteStatusLabel(intl, invite.status.v),
                badges: [
                  FkStatusPill(
                    AdminAccessRole.of(invite).label(intl),
                    status: AdminAccessRole.of(invite).status,
                  ),
                ],
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: intl.projectEmailInviteRevoke,
                  onPressed: _busy
                      ? null
                      : () => _revokeEmailInvite(context, bloc, invite),
                ),
              ),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<ProjectSdbShareScreenBloc>(context);
    return Scaffold(
      appBar: AppBar(title: Text(intl.projectShare)),
      body: ValueStreamBuilder<ProjectSdbShareScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var state = snapshot.data;
          var project = state?.project;
          if (state == null || project == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!_accessInitialized) {
            _initAccess(project);
          }
          return FkPage(
            maxWidth: FestenaoSpace.readingWidth,
            children: [
              FkHeader(title: project.name ?? ''),
              FkSectionTitle(intl.projectAccessRole),
              _buildRole(context, intl),
              const SizedBox(height: FestenaoSpace.xl),
              FkSectionTitle(intl.projectInviteLink),
              _buildLink(context, intl, bloc, state),
              if (bloc.emailInvitesSupported && project.isAdmin)
                ..._buildEmailInvites(context, intl, bloc, state),
            ],
          );
        },
      ),
    );
  }
}

/// Navigate to the project share screen.
Future<void> goToProjectSdbShareScreen(
  BuildContext context, {
  required String projectId,
  UserProjectsSdb? projectsDb,
  TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity>? entityAccess,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) {
        return BlocProvider<ProjectSdbShareScreenBloc>(
          blocBuilder: () => ProjectSdbShareScreenBloc(
            projectId: projectId,
            projectsDb: projectsDb,
            entityAccess: entityAccess,
          ),
          child: const ProjectSdbShareScreen(),
        );
      },
    ),
  );
}

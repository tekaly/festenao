import 'package:barcode_widget/barcode_widget.dart';
import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/utils/project_ui_utils.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_invite_view_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_share_screen_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Project share screen: generate an invite (a link) with a given access
/// level, and send invites by email (addressed invites, for an admin, when
/// the secured api is there).
///
/// Dashboard counterpart of Notelio's `BookletShareScreen`.
class ProjectSdbShareScreen extends StatefulWidget {
  const ProjectSdbShareScreen({super.key});

  @override
  State<ProjectSdbShareScreen> createState() => _ProjectSdbShareScreenState();
}

class _ProjectSdbShareScreenState
    extends AutoDisposeBaseState<ProjectSdbShareScreen> {
  bool _admin = false;
  bool _write = false;
  bool _read = true;
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
    _admin = project.isAdmin;
    _write = project.isWrite || project.isAdmin;
    _read = project.isRead || project.isWrite || project.isAdmin;
  }

  Future<void> _share(
    BuildContext context,
    ProjectSdbShareScreenBloc bloc,
  ) async {
    setState(() => _busy = true);
    try {
      await bloc.createInvite(admin: _admin, write: _write, read: _read);
    } catch (e) {
      if (context.mounted) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('share error: $e');
        }
        await muiSnack(context, 'Erreur: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteInvite(
    BuildContext context,
    ProjectSdbShareScreenBloc bloc,
    String inviteId,
  ) async {
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'invitation'),
        content: const Text(
          'Voulez-vous vraiment supprimer cette invitation ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
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
    try {
      var result = await bloc.createEmailInvite(
        email: email,
        admin: _admin,
        write: _write,
        read: _read,
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
        await muiSnack(context, 'Erreur: $e');
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
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(intl.projectEmailInviteRevoke),
        content: Text(
          intl.projectEmailInviteRevokeConfirm(invite.email.v ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(intl.cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(intl.projectEmailInviteRevoke),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _busy = true);
      try {
        await bloc.deleteEmailInvite(invite.inviteId.v!);
      } catch (e) {
        if (context.mounted) {
          await muiSnack(context, 'Erreur: $e');
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

  /// The email invites section: an admin sends addressed invites and sees
  /// what happened to the ones sent (request and response, nothing streams:
  /// no client reads this data).
  List<Widget> _buildEmailInvites(
    BuildContext context,
    AppLocalizations intl,
    ProjectSdbShareScreenBloc bloc,
    ProjectSdbShareScreenBlocState state,
  ) {
    var textTheme = Theme.of(context).textTheme;
    var emailInvites = state.emailInvites;
    var error = state.emailInvitesError;
    var canSend = !_busy && _read;
    return [
      const Divider(height: 48),
      Text(intl.projectEmailInviteTitle, style: textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(intl.projectEmailInviteInformation),
      const SizedBox(height: 16),
      TextField(
        controller: _emailController,
        enabled: !_busy,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: intl.projectEmailInviteEmailLabel,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: canSend ? (_) => _sendEmailInvite(context, bloc) : null,
      ),
      const SizedBox(height: 8),
      Center(
        child: ElevatedButton.icon(
          onPressed: canSend ? () => _sendEmailInvite(context, bloc) : null,
          icon: const Icon(Icons.mail_outline),
          label: Text(intl.projectEmailInviteSend),
        ),
      ),
      const SizedBox(height: 16),
      Text(intl.projectEmailInviteListTitle, style: textTheme.titleSmall),
      if (error != null)
        Text('Erreur: $error')
      else if (emailInvites == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: LinearProgressIndicator(),
        )
      else if (emailInvites.isEmpty)
        Text(intl.projectEmailInviteNone)
      else
        for (var invite in emailInvites)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_emailInviteStatusIcon(invite.status.v)),
            title: Text(invite.email.v ?? ''),
            subtitle: Text(
              '${accessString(intl, invite)} · '
              '${_emailInviteStatusLabel(intl, invite.status.v)}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: intl.projectEmailInviteRevoke,
              onPressed: _busy
                  ? null
                  : () => _revokeEmailInvite(context, bloc, invite),
            ),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<ProjectSdbShareScreenBloc>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Partager')),
      body: ValueStreamBuilder<ProjectSdbShareScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var state = snapshot.data;
          if (state == null) {
            return const Center(child: CircularProgressIndicator());
          }
          var project = state.project;
          if (project == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!_accessInitialized) {
            _initAccess(project);
          }
          var canEditSharing = !_busy && state.canEditSharing;
          var canShare = canEditSharing && _read;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                project.name ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const Text(
                'Choisissez le niveau d\'accès accordé par l\'invitation.',
              ),
              CheckboxListTile(
                title: Text(intl.projectAccessAdmin),
                value: _admin,
                onChanged: canEditSharing && project.isAdmin
                    ? (on) {
                        setState(() {
                          _admin = on ?? false;
                          if (_admin) {
                            _write = true;
                            _read = true;
                          }
                        });
                      }
                    : null,
              ),
              CheckboxListTile(
                title: Text(intl.projectAccessWrite),
                value: _write,
                onChanged:
                    canEditSharing && (project.isWrite || project.isAdmin)
                    ? (on) {
                        setState(() {
                          _write = on ?? false;
                          if (_write) {
                            _read = true;
                          } else {
                            _admin = false;
                          }
                        });
                      }
                    : null,
              ),
              CheckboxListTile(
                title: Text(intl.projectAccessRead),
                value: _read,
                onChanged: canEditSharing
                    ? (on) {
                        setState(() {
                          _read = on ?? false;
                          if (!_read) {
                            _write = false;
                            _admin = false;
                          }
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: canShare ? () => _share(context, bloc) : null,
                  icon: const Icon(Icons.share),
                  label: const Text('Générer une invitation'),
                ),
              ),
              if (state.canViewInvite) ...[
                const Divider(height: 48),
                const Text('Lien d\'invitation'),
                Builder(
                  builder: (context) {
                    var link = ProjectSdbInviteViewScreen.inviteLink(
                      bloc.projectId,
                      state.inviteId!,
                    );
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            link,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('id: ${state.inviteId}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            tooltip: 'Copier',
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: link),
                              );
                              if (context.mounted) {
                                await muiSnack(context, 'Copié');
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            var size = constraints.maxWidth < 320
                                ? constraints.maxWidth
                                : 320.0;
                            return Center(
                              child: Container(
                                width: size,
                                height: size,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: BarcodeWidget(
                                  barcode: Barcode.qrCode(
                                    errorCorrectLevel:
                                        BarcodeQRCorrectionLevel.high,
                                  ),
                                  data: link,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                if (kDebugMode)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.open_in_new),
                    title: const Text('[debug] Ouvrir l\'invitation'),
                    onTap: () => goToProjectSdbInviteViewScreen(
                      context,
                      projectId: bloc.projectId,
                      inviteId: state.inviteId!,
                      entityAccess: bloc.entityAccess,
                      projectsDb: bloc.projectsDb,
                    ),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Supprimer l\'invitation'),
                  onTap: _busy
                      ? null
                      : () => _deleteInvite(context, bloc, state.inviteId!),
                ),
              ],
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

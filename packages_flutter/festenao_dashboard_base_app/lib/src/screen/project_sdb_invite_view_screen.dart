import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/utils/project_ui_utils.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_invite_view_screen_bloc.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

/// Result of viewing an invite.
class ProjectSdbInviteViewResult {
  final bool accepted;
  final bool deleted;

  ProjectSdbInviteViewResult({this.accepted = false, this.deleted = false});
}

/// Screen to view and accept (or delete) a project invite.
///
/// Dashboard counterpart of Notelio's `BookletInviteViewScreen`.
class ProjectSdbInviteViewScreen extends StatefulWidget {
  /// To set on start until a better solution is found
  static String? baseUrl;
  const ProjectSdbInviteViewScreen({super.key});

  /// Relative deep-link path for an invite. The consuming app maps this to a
  /// route that opens this screen.
  static String inviteLink(String projectId, String inviteId) =>
      '${baseUrl ?? Uri.base.toString()}project/$projectId/invite/$inviteId';

  @override
  State<ProjectSdbInviteViewScreen> createState() =>
      _ProjectSdbInviteViewScreenState();
}

class _ProjectSdbInviteViewScreenState
    extends AutoDisposeBaseState<ProjectSdbInviteViewScreen> {
  bool _busy = false;
  bool _admin = false;
  bool _write = false;
  bool _read = true;

  Future<void> _updateRole(
    BuildContext context,
    ProjectSdbInviteViewScreenBloc bloc, {
    required bool admin,
    required bool write,
    required bool read,
  }) async {
    setState(() => _busy = true);
    try {
      await bloc.updateInviteAccess(admin: admin, write: write, read: read);
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

  Future<void> _accept(
    BuildContext context,
    ProjectSdbInviteViewScreenBloc bloc,
  ) async {
    var intl = festenaoAdminAppIntl(context);
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accepter l\'invitation'),
        content: const Text('Rejoindre ce projet avec l\'accès proposé ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(intl.cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accepter'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      await bloc.acceptInvite();
      if (context.mounted) {
        Navigator.pop(context, ProjectSdbInviteViewResult(accepted: true));
      }
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

  Future<void> _delete(
    BuildContext context,
    ProjectSdbInviteViewScreenBloc bloc,
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
      await bloc.deleteInvite();
      if (context.mounted) {
        Navigator.pop(context, ProjectSdbInviteViewResult(deleted: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<ProjectSdbInviteViewScreenBloc>(context);
    return ValueStreamBuilder<ProjectSdbInviteViewScreenBlocState>(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        var invite = state?.invite;
        var user = state?.user;
        var canAccept = !_busy && (invite?.exists ?? false) && user != null;
        var canEditRole = canAccept && (state?.userProject?.isAdmin ?? false);

        if (invite != null && invite.exists && !_busy) {
          var ua = invite.userAccess.v!;
          _admin = ua.admin.v ?? false;
          _write = ua.write.v ?? false;
          _read = ua.read.v ?? false;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Invitation'),
            actions: [
              if (canAccept)
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: intl.deleteButtonLabel,
                  onPressed: () => _delete(context, bloc),
                ),
            ],
          ),
          body: state == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (user == null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Vous devez être connecté pour accepter cette '
                        'invitation.',
                      ),
                    ] else if (state.accepted) ...[
                      const SizedBox(height: 16),
                      const Text('Invitation acceptée.'),
                    ] else if (invite?.exists != true) ...[
                      const SizedBox(height: 16),
                      const Text('Invitation introuvable ou expirée.'),
                    ] else ...[
                      const SizedBox(height: 16),
                      const Text('Vous avez été invité à rejoindre ce projet.'),
                      const SizedBox(height: 16),
                      ListTile(
                        title: Text(invite!.entity.v?.name.v ?? '(projet)'),
                        subtitle: canEditRole
                            ? const Text('Niveau d\'accès (Édition)')
                            : accessText(intl, invite.userAccess.v!),
                      ),
                      if (canEditRole) ...[
                        CheckboxListTile(
                          title: Text(intl.projectAccessAdmin),
                          value: _admin,
                          onChanged: !_busy
                              ? (on) {
                                  var newAdmin = on ?? false;
                                  var newWrite = _write;
                                  var newRead = _read;
                                  if (newAdmin) {
                                    newWrite = true;
                                    newRead = true;
                                  }
                                  _updateRole(
                                    context,
                                    bloc,
                                    admin: newAdmin,
                                    write: newWrite,
                                    read: newRead,
                                  );
                                }
                              : null,
                        ),
                        CheckboxListTile(
                          title: Text(intl.projectAccessWrite),
                          value: _write,
                          onChanged: !_busy
                              ? (on) {
                                  var newWrite = on ?? false;
                                  var newAdmin = _admin;
                                  var newRead = _read;
                                  if (newWrite) {
                                    newRead = true;
                                  } else {
                                    newAdmin = false;
                                  }
                                  _updateRole(
                                    context,
                                    bloc,
                                    admin: newAdmin,
                                    write: newWrite,
                                    read: newRead,
                                  );
                                }
                              : null,
                        ),
                        CheckboxListTile(
                          title: Text(intl.projectAccessRead),
                          value: _read,
                          onChanged: !_busy
                              ? (on) {
                                  var newRead = on ?? false;
                                  var newWrite = _write;
                                  var newAdmin = _admin;
                                  if (!newRead) {
                                    newWrite = false;
                                    newAdmin = false;
                                  }
                                  _updateRole(
                                    context,
                                    bloc,
                                    admin: newAdmin,
                                    write: newWrite,
                                    read: newRead,
                                  );
                                }
                              : null,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: () => _accept(context, bloc),
                          child: const Text('Accepter l\'invitation'),
                        ),
                      ),
                    ],
                  ],
                ),
          floatingActionButton: canAccept
              ? FloatingActionButton(
                  tooltip: 'Accepter',
                  onPressed: () => _accept(context, bloc),
                  child: const Icon(Icons.check),
                )
              : null,
        );
      },
    );
  }
}

/// Navigate to the invite view screen.
Future<ProjectSdbInviteViewResult?> goToProjectSdbInviteViewScreen(
  BuildContext context, {
  required String projectId,
  required String inviteId,
}) async {
  return await Navigator.of(context).push(
    MaterialPageRoute<ProjectSdbInviteViewResult>(
      builder: (_) {
        return BlocProvider<ProjectSdbInviteViewScreenBloc>(
          blocBuilder: () => ProjectSdbInviteViewScreenBloc(
            projectId: projectId,
            inviteId: inviteId,
          ),
          child: const ProjectSdbInviteViewScreen(),
        );
      },
    ),
  );
}

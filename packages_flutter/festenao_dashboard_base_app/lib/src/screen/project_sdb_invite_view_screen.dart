import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/view/access_view.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_invite_view_screen_bloc.dart';
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/kit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Result of viewing an invite.
class ProjectSdbInviteViewResult {
  final bool accepted;
  final bool deleted;

  ProjectSdbInviteViewResult({this.accepted = false, this.deleted = false});
}

/// Screen to view and accept (or delete) a project invite, on the festenao
/// kit: the project and the role given, accept; an admin of the project
/// changes the role.
///
/// Dashboard counterpart of Notelio's `BookletInviteViewScreen`.
class ProjectSdbInviteViewScreen extends StatefulWidget {
  /// To set on start until a better solution is found
  static String? baseUrl;
  const ProjectSdbInviteViewScreen({super.key});

  /// Builds the invite deep link, for apps whose invite route does not have
  /// the default `project/<id>/invite/<id>` shape (a songbook invite...).
  ///
  /// Set it once at startup, next to the other app wiring.
  static String Function(String entityId, String inviteId)? inviteLinkBuilder;

  /// Deep link of an invite, the app maps it to the route opening this screen.
  ///
  /// The default is `<origin>/project/<projectId>/invite/<inviteId>`; set
  /// [baseUrl] to serve the app from a sub path, or [inviteLinkBuilder] to
  /// change the shape entirely.
  static String inviteLink(String projectId, String inviteId) {
    var builder = inviteLinkBuilder;
    if (builder != null) {
      return builder(projectId, inviteId);
    }
    return '${baseUrl ?? defaultInviteBaseUrl}'
        'project/$projectId/invite/$inviteId';
  }

  /// The origin of the app, with a trailing `/`.
  ///
  /// The origin, not `Uri.base`: the latter is the *current* location, so
  /// sharing from a nested screen used to yield a mangled link. Off the web
  /// there is no origin (`Uri.base` is a `file:` uri), the link is then
  /// relative.
  static String get defaultInviteBaseUrl {
    var base = Uri.base;
    if (base.isScheme('http') || base.isScheme('https')) {
      return '${base.origin}/';
    }
    return '/';
  }

  @override
  State<ProjectSdbInviteViewScreen> createState() =>
      _ProjectSdbInviteViewScreenState();
}

class _ProjectSdbInviteViewScreenState
    extends AutoDisposeBaseState<ProjectSdbInviteViewScreen> {
  bool _busy = false;

  Future<void> _updateRole(
    BuildContext context,
    ProjectSdbInviteViewScreenBloc bloc,
    AdminAccessRole role,
  ) async {
    setState(() => _busy = true);
    var flags = role.flags;
    try {
      await bloc.updateInviteAccess(
        admin: flags.admin,
        write: flags.write,
        read: flags.read,
      );
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

  Future<void> _accept(
    BuildContext context,
    ProjectSdbInviteViewScreenBloc bloc,
  ) async {
    var intl = festenaoAdminAppIntl(context);
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(intl.projectInviteAccept),
        content: Text(intl.projectInviteAcceptConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(intl.cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(intl.projectInviteAccept),
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
        await muiSnack(context, 'Error: $e');
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
    var intl = festenaoAdminAppIntl(context);
    var t = context.festenao;
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(intl.projectInviteDelete),
        content: Text(intl.projectInviteDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(intl.cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: t.bad),
            child: Text(intl.deleteButtonLabel),
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
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    var bloc = BlocProvider.of<ProjectSdbInviteViewScreenBloc>(context);
    return ValueStreamBuilder<ProjectSdbInviteViewScreenBlocState>(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        var invite = state?.invite;
        var user = state?.user;
        var canAccept = !_busy && (invite?.exists ?? false) && user != null;
        var canEditRole = canAccept && (state?.userProject?.isAdmin ?? false);

        Widget body;
        if (state == null) {
          body = const Center(child: CircularProgressIndicator());
        } else {
          Widget content;
          if (user == null) {
            content = FkCard(
              child: FkEmpty(
                icon: Icons.login,
                message: intl.projectInviteMustBeLoggedIn,
              ),
            );
          } else if (state.accepted) {
            content = FkCard(
              child: FkEmpty(
                icon: Icons.check_circle_outline,
                message: intl.projectInviteAccepted,
              ),
            );
          } else if (invite?.exists != true) {
            content = FkCard(
              child: FkEmpty(
                icon: Icons.link_off,
                message: intl.projectInviteNotFound,
              ),
            );
          } else {
            var access = invite!.userAccess.v!;
            var role = AdminAccessRole.of(access);
            var entityName = invite.entity.v?.name.v ?? bloc.projectId;
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FkCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FkAvatar(
                            entityName,
                            category: adminAccessCategory(bloc.projectId),
                            size: 56,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  intl.projectInviteMessage,
                                  style: text.bodyMedium?.copyWith(
                                    color: t.ink2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(entityName, style: text.titleLarge),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    FkStatusPill(
                                      role.label(intl),
                                      status: role.status,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: canAccept
                                ? () => _accept(context, bloc)
                                : null,
                            icon: const Icon(Icons.check),
                            label: Text(intl.projectInviteAccept),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (canEditRole) ...[
                  const SizedBox(height: FestenaoSpace.xl),
                  FkSectionTitle(intl.projectAccessRole),
                  FkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          intl.projectInviteRoleEdit,
                          style: text.bodyMedium?.copyWith(color: t.ink2),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<AdminAccessRole>(
                          showSelectedIcon: false,
                          emptySelectionAllowed: true,
                          segments: [
                            for (var choice in AdminAccessRole.assignable)
                              ButtonSegment(
                                value: choice,
                                label: Text(choice.label(intl)),
                              ),
                          ],
                          selected: {if (role != AdminAccessRole.none) role},
                          onSelectionChanged:
                              _busy || role == AdminAccessRole.none
                              ? null
                              : (selection) => _updateRole(
                                  context,
                                  bloc,
                                  selection.isEmpty ? role : selection.first,
                                ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: t.ink3),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                role.detail(intl),
                                style: text.bodySmall?.copyWith(color: t.ink2),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          }
          body = FkPage(
            maxWidth: FestenaoSpace.readingWidth,
            children: [content],
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(intl.projectInviteTitle),
            actions: [
              if (canAccept)
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: intl.deleteButtonLabel,
                  onPressed: () => _delete(context, bloc),
                ),
            ],
          ),
          body: body,
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
  TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity>? entityAccess,
  UserProjectsSdb? projectsDb,
  Future<void> Function({required String entityId, required String inviteId})?
  onAcceptInvite,
  Future<void> Function({required String entityId, required String inviteId})?
  onDeleteInvite,
}) async {
  return await Navigator.of(context).push(
    MaterialPageRoute<ProjectSdbInviteViewResult>(
      builder: (_) {
        return BlocProvider<ProjectSdbInviteViewScreenBloc>(
          blocBuilder: () => ProjectSdbInviteViewScreenBloc(
            projectId: projectId,
            inviteId: inviteId,
            entityAccess: entityAccess,
            projectsDb: projectsDb,
            onAcceptInvite: onAcceptInvite,
            onDeleteInvite: onDeleteInvite,
          ),
          child: const ProjectSdbInviteViewScreen(),
        );
      },
    ),
  );
}

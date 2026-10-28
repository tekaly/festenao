import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/view/access_view.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common_flutter/share_link.dart';
import 'package:festenao_dashboard_base_app/src/provider/project_access_providers.dart';
import 'package:festenao_dashboard_base_app/src/provider/project_slug_providers.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_share_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_users_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/projects_access_screen.dart';
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/kit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

import 'project_sdb_edit_screen.dart';
import 'project_slug_screen.dart';
import 'project_slugs_screen.dart';

/// What the access screen pops when the entity is gone.
class ProjectViewResult {
  /// True when the entity was deleted or left.
  final bool deleted;

  /// The result of the access screen.
  ProjectViewResult({required this.deleted});
}

/// The access screen of one entity, on the festenao kit: a header card (its
/// name, the role of the signed in user, edit), the access rows (users,
/// share / invite), its details (url, id, role) and the leave / delete
/// actions.
///
/// It works on any [TkCmsFsEntity]. Which one is scoped, not passed down: the
/// route overrides [currentEntityAccessProvider] (and
/// [currentProjectsMirrorDbProvider] when the entity has no local mirror), so
/// the same screen serves a festenao project, a playelio playlist and a
/// songbookelio songbook.
class ProjectViewScreen extends ConsumerStatefulWidget {
  /// The firestore id of the entity.
  final String entityId;

  /// The access screen of the entity [entityId].
  const ProjectViewScreen({super.key, required this.entityId});

  @override
  ConsumerState<ProjectViewScreen> createState() => ProjectViewScreenState();
}

/// The state of [ProjectViewScreen].
class ProjectViewScreenState extends ConsumerState<ProjectViewScreen>
    with AutoDisposeMixin, AutoDisposedBusyScreenStateMixin<ProjectViewScreen> {
  String get _entityId => widget.entityId;

  RpdProjectAccess get _access =>
      ref.read(rpdProjectAccessProvider(_entityId).notifier);

  @override
  void dispose() {
    audiDisposeAll();
    super.dispose();
  }

  /// Asks for a confirmation, then runs [action] and pops on success.
  Future<void> _confirmAndRun(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmLabel,
    required Future<void> Function() action,
  }) async {
    var intl = festenaoAdminAppIntl(context);
    var t = context.festenao;
    var result = await busyAction(() async {
      if (await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(title),
                content: Text(content),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(intl.cancelButtonLabel),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    style: TextButton.styleFrom(foregroundColor: t.bad),
                    child: Text(confirmLabel),
                  ),
                ],
              );
            },
          ) ==
          true) {
        await action();
        return true;
      } else {
        return false;
      }
    });
    if (!result.busy) {
      if (result.error != null) {
        if (context.mounted) {
          await muiSnack(context, result.error!.toString());
        }
      } else if (result.result == true) {
        if (context.mounted) {
          Navigator.pop(context, ProjectViewResult(deleted: true));
        }
      }
    }
  }

  Future<void> _confirmAndDelete(BuildContext context) async {
    var intl = festenaoAdminAppIntl(context);
    await _confirmAndRun(
      context,
      title: intl.projectDelete,
      content: intl.projectDeleteConfirm,
      confirmLabel: intl.deleteButtonLabel,
      action: _access.deleteEntity,
    );
  }

  Future<void> _confirmAndLeave(BuildContext context) async {
    var intl = festenaoAdminAppIntl(context);
    await _confirmAndRun(
      context,
      title: intl.projectLeave,
      content: intl.projectLeaveConfirm,
      confirmLabel: intl.leaveButtonLabel,
      action: _access.leaveEntity,
    );
  }

  Future<void> _copy(BuildContext context, String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      await muiSnack(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    var state = ref.watch(rpdProjectAccessProvider(_entityId)).value;
    var project = state?.project;
    var fsProject = state?.fsProject;
    var fsProjectAccess = state?.fsUserAccess;
    var dbProjectReady = state?.dbProjectReady ?? false;
    // The entity is known either from the local mirror or from firestore.
    var hasEntity = project != null || fsProject != null;
    var canEdit = project?.isWrite ?? fsProjectAccess?.isWrite ?? false;
    var canDelete = project?.isAdmin ?? fsProjectAccess?.isAdmin ?? false;
    var projectName = project?.name.v ?? fsProject?.name.v;
    var name = projectName ?? _entityId;
    var role = project != null
        ? dashboardProjectRole(project)
        : AdminAccessRole.of(fsProjectAccess ?? TkCmsFsUserAccess());
    // A project opens at its slug, or at its id without one.
    var hasUrl = ref.watch(dashboardEntityHasUrlProvider);
    var slug = ref.watch(dashboardEntitySlugProvider(_entityId)).value;
    var link = hasUrl
        ? appShareLink(dashboardProjectSlugLocation(slug ?? _entityId))
        : null;
    var mono = text.bodyMedium?.copyWith(fontFamily: t.monoFamily);

    void openUsers() {
      goToProjectSdbUsersScreen(
        context,
        projectId: _entityId,
        entityAccess: ref.read(currentEntityAccessProvider),
      );
    }

    void openShare() {
      goToProjectSdbShareScreen(
        context,
        projectId: _entityId,
        projectsDb: ref.read(currentProjectsMirrorDbProvider),
        entityAccess: ref.read(currentEntityAccessProvider),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(projectName ?? '')),
      body: !dbProjectReady
          ? const Center(child: CircularProgressIndicator())
          : FkPage(
              maxWidth: FestenaoSpace.readingWidth,
              children: [
                FkCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FkAvatar(
                            name,
                            category: adminAccessCategory(_entityId),
                            size: 56,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: text.titleLarge),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    FkStatusPill(
                                      role.label(intl),
                                      status: role.status,
                                    ),
                                    if (project != null)
                                      FkStatusPill(
                                        intl.projectTypeSynced,
                                        status: FkStatus.ok,
                                        dot: true,
                                      )
                                    else if (hasEntity)
                                      FkStatusPill(
                                        intl.projectNotSyncedYet,
                                        status: FkStatus.warn,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (canEdit && project != null) ...[
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () async {
                                await goToProjectEditScreen(
                                  context,
                                  project: project,
                                );
                              },
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(intl.accessEdit),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: FestenaoSpace.xl),
                FkSectionTitle(intl.accessTitle),
                FkListCard(
                  children: [
                    FkRow(
                      leading: const FkIconBox(Icons.group_outlined),
                      title: intl.projectUsersTitle,
                      subtitle: intl.accessSubtitle,
                      trailing: Icon(Icons.chevron_right, color: t.ink3),
                      onTap: hasEntity ? openUsers : null,
                    ),
                    FkRow(
                      leading: const FkIconBox(Icons.share_outlined),
                      title: intl.projectShareInvite,
                      subtitle: intl.projectShareInviteDetail,
                      trailing: Icon(Icons.chevron_right, color: t.ink3),
                      onTap: hasEntity ? openShare : null,
                    ),
                  ],
                ),
                const SizedBox(height: FestenaoSpace.xl),
                FkSectionTitle(intl.projectDetailsSection),
                FkListCard(
                  children: [
                    if (link != null) ...[
                      FkKeyValueRow(
                        label: intl.projectUrl,
                        value: link,
                        trailing: IconButton(
                          tooltip: intl.copyButtonLabel,
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () =>
                              _copy(context, link, intl.linkCopied),
                        ),
                      ),
                      FkRow(
                        leading: const FkIconBox(Icons.link),
                        title: intl.projectUrls,
                        subtitle: intl.projectUrlsDetail,
                        trailing: Icon(Icons.chevron_right, color: t.ink3),
                        onTap: hasEntity
                            ? () => goToDashboardProjectSlugsScreen(
                                context,
                                projectId: _entityId,
                              )
                            : null,
                      ),
                    ],
                    FkKeyValueRow(
                      label: intl.projectIdLabel,
                      value: _entityId,
                      valueStyle: mono,
                      trailing: IconButton(
                        tooltip: intl.copyButtonLabel,
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () =>
                            _copy(context, _entityId, intl.accessIdCopied),
                      ),
                    ),
                    FkKeyValueRow(
                      label: intl.projectYourRole,
                      value: '${role.label(intl)} · ${role.detail(intl)}',
                    ),
                  ],
                ),
                const SizedBox(height: FestenaoSpace.xl),
                FkListCard(
                  children: [
                    FkRow(
                      leading: FkIconBox(Icons.logout, color: t.warn),
                      title: intl.projectLeave,
                      subtitle: intl.projectLeaveDetail,
                      trailing: Icon(Icons.chevron_right, color: t.ink3),
                      onTap: hasEntity ? () => _confirmAndLeave(context) : null,
                    ),
                    if (canDelete)
                      FkRow(
                        leading: FkIconBox(Icons.delete_outline, color: t.bad),
                        title: intl.projectDelete,
                        titleColor: t.bad,
                        subtitle: intl.projectDeleteDetail,
                        trailing: Icon(Icons.chevron_right, color: t.ink3),
                        onTap: hasEntity
                            ? () => _confirmAndDelete(context)
                            : null,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Opens the access screen of [projectId] through the content navigator.
///
/// The entry point of the apps still navigating with `ContentNavigator` rather
/// than go_router (`festenaoprv_admin_app`); a go_router app pushes
/// `projectAccessPath` instead.
Future<void> goToProjectViewScreen(
  BuildContext context, {
  required String projectId,
}) async {
  var cn = ContentNavigator.of(context);
  await cn.pushPath<void>(
    SyncedProjectContentPath()..project.value = projectId,
  );
}

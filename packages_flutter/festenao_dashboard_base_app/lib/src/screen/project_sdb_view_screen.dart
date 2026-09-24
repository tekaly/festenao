import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/utils/project_ui_utils.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_dashboard_base_app/src/provider/project_access_providers.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_share_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_user_app/theme/theme1.dart';
import 'package:tkcms_user_app/view/body_container.dart';

import 'project_sdb_edit_screen.dart';
import 'project_slug_screen.dart';

/// What the access screen pops when the entity is gone.
class ProjectViewResult {
  /// True when the entity was deleted or left.
  final bool deleted;

  /// The result of the access screen.
  ProjectViewResult({required this.deleted});
}

/// The access screen of one entity: what it is, who can reach it, and the
/// share / leave / delete actions.
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

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
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

    var children = <Widget>[
      BodyHPadding(
        child: Text(
          projectName ?? '',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      if (project != null)
        ListTile(
          leading: const Icon(Icons.folder),
          title: Text(intl.projectTypeSynced),
          subtitle: accessText(intl, project),
        )
      else if (fsProject != null) ...[
        ListTile(
          title: Text(fsProject.name.v ?? ''),
          subtitle: accessText(intl, fsProjectAccess ?? TkCmsFsUserAccess()),
        ),
      ],
      DashboardProjectUrlTile(entityId: _entityId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(projectName ?? ''),
        actions: !hasEntity
            ? null
            : <Widget>[
                if (canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      await _confirmAndDelete(context);
                    },
                  ),
              ],
      ),
      body: !dbProjectReady
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                BodyContainer(
                  child: BodyHPadding(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(),
                        ...children,
                        Center(
                          child: IntrinsicWidth(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: hasEntity
                                      ? () {
                                          goToProjectSdbUsersScreen(
                                            context,
                                            projectId: _entityId,
                                            entityAccess: ref.read(
                                              currentEntityAccessProvider,
                                            ),
                                          );
                                        }
                                      : null,
                                  icon: const Icon(Icons.people),
                                  label: const Text('Utilisateurs'),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: hasEntity
                                      ? () {
                                          goToProjectSdbShareScreen(
                                            context,
                                            projectId: _entityId,
                                            projectsDb: ref.read(
                                              currentProjectsMirrorDbProvider,
                                            ),
                                            entityAccess: ref.read(
                                              currentEntityAccessProvider,
                                            ),
                                          );
                                        }
                                      : null,
                                  icon: const Icon(Icons.share),
                                  label: const Text('Partager / Inviter'),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: hasEntity
                                      ? () {
                                          _confirmAndLeave(context);
                                        }
                                      : null,
                                  child: Text(intl.projectLeave),
                                ),
                                if (canDelete) ...[
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorError,
                                    ),
                                    onPressed: hasEntity
                                        ? () {
                                            _confirmAndDelete(context);
                                          }
                                        : null,
                                    child: Text(intl.projectDelete),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 64),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              tooltip: 'Edit',
              onPressed: () async {
                await goToProjectEditScreen(context, project: project!);
              },
              child: const Icon(Icons.edit),
            )
          : null,
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

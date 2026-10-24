import 'dart:async';

import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_admin_base_app/view/access_view.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/src/provider/project_access_providers.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_dashboard_base_app/src/screen/pending_email_invites_view.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_leading.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_edit_screen.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The projects the signed in user has access to, on the festenao kit: a
/// row per project with its avatar, id and role, the pending email invites
/// above, a button creating a project.
///
/// Everything it shows comes from [rpdProjectsAccessProvider]: watching it is
/// also what keeps the local project list mirrored from firestore.
class DashboardProjectsAccessScreen extends ConsumerWidget {
  /// The route name.
  static const routeName = 'projects_access';

  /// The route location.
  static const routeLocation = '/projects_access';

  /// True when the screen is used to pick a project: tapping one pops a
  /// [SelectProjectResult] instead of opening its access screen.
  final bool selectMode;

  /// The projects access screen.
  const DashboardProjectsAccessScreen({super.key, this.selectMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var intl = festenaoAdminAppIntl(context);
    var access = ref.watch(rpdProjectsAccessProvider);
    // The scaffold is built whatever the state is, so the app bar (and its back
    // button, for a location opened directly) is there while the projects load.
    return FestenaoAdminAppScaffold(
      appBar: AppBar(
        title: Text(intl.projectsTitle),
        actions: [
          IconButton(
            tooltip: intl.syncNow,
            onPressed: () {
              unawaited(
                ref.read(rpdProjectsAccessProvider.notifier).syncUserProjects(),
              );
            },
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: access.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('error: $error')),
        data: (state) => _ProjectList(state: state, selectMode: selectMode),
      ),
    );
  }
}

/// The role of the signed in user on [project].
AdminAccessRole dashboardProjectRole(SdbUserProject project) =>
    AdminAccessRole.ofFlags(
      admin: project.isAdmin,
      write: project.isWrite,
      read: project.isRead,
    );

/// The project list, with the pending email invites of the user on top, an
/// empty state when there is none, a signed out state.
class _ProjectList extends StatelessWidget {
  final ProjectsAccessState state;
  final bool selectMode;

  const _ProjectList({required this.state, required this.selectMode});

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var t = context.festenao;
    var projects = state.projects;
    var signedIn = state.identity != null;
    return FkPage(
      maxWidth: 960,
      children: [
        FkHeader(
          subtitle: intl.projectsSubtitle,
          actions: [
            if (signedIn)
              FilledButton.icon(
                onPressed: () async {
                  await goToProjectEditScreen(context, project: null);
                },
                icon: const Icon(Icons.add),
                label: Text(intl.projectNew),
              ),
          ],
        ),
        if (signedIn) const PendingEmailInvitesView(),
        if (!signedIn)
          FkCard(
            child: FkEmpty(
              icon: Icons.person_outline,
              message: intl.notSignedInInfo,
            ),
          )
        else if (projects.isEmpty)
          FkCard(
            child: FkEmpty(
              icon: Icons.folder_open_outlined,
              message: intl.projectsNone,
            ),
          )
        else
          FkListCard(
            children: [
              for (var project in projects)
                FkRow(
                  leading: ProjectLeading(project: project),
                  title: project.name.v ?? project.fsId,
                  subtitle: project.name.v == null ? null : project.fsId,
                  badges: [
                    FkStatusPill(
                      dashboardProjectRole(project).label(intl),
                      status: dashboardProjectRole(project).status,
                    ),
                  ],
                  trailing: Icon(Icons.chevron_right, color: t.ink3),
                  onTap: () async {
                    var projectId = project.fsId;
                    if (selectMode) {
                      Navigator.of(context)
                          .pop(SelectProjectResult(projectId: projectId));
                    } else {
                      await context.pushPath<void>(
                        projectAccessPath,
                        parameters: {DashboardRouteParams.projectId: projectId},
                      );
                    }
                  },
                ),
            ],
          ),
      ],
    );
  }
}

/// The project picked by [selectProject].
class SelectProjectResult {
  /// The firestore id of the picked project.
  final String projectId;

  /// The project picked by [selectProject].
  SelectProjectResult({required this.projectId});

  @override
  String toString() => 'SelectProjectResult{projectRef: $projectId}';
}

/// Opens the projects screen to pick one, null when the user backs out.
Future<SelectProjectResult?> selectProject(BuildContext context) async {
  var result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder: (_) => const DashboardProjectsAccessScreen(selectMode: true),
    ),
  );
  if (result is SelectProjectResult) {
    return result;
  }
  return null;
}

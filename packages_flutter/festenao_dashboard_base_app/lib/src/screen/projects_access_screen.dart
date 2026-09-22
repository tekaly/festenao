import 'dart:async';

import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_dashboard_base_app/src/provider/project_access_providers.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_leading.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_edit_screen.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/with_header_footer_list_view.dart';
import 'package:tkcms_admin_app/view/trailing_arrow.dart';

/// The projects the signed in user has access to.
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
    var access = ref.watch(rpdProjectsAccessProvider);
    // The scaffold is built whatever the state is, so the app bar (and its back
    // button, for a location opened directly) is there while the projects load.
    return FestenaoAdminAppScaffold(
      appBar: AppBar(
        title: const Text('Dashboard Projects prv sdb'),
        actions: [
          IconButton(
            tooltip: 'Sync projects from access list',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await goToProjectEditScreen(context, project: null);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// The project list, with a footer inviting a signed out user to sign in.
class _ProjectList extends StatelessWidget {
  final ProjectsAccessState state;
  final bool selectMode;

  const _ProjectList({required this.state, required this.selectMode});

  @override
  Widget build(BuildContext context) {
    var projects = state.projects;
    return WithHeaderFooterListView.builder(
      footer: state.identity == null
          ? const BodyContainer(
              child: BodyHPadding(
                child: Center(
                  child: Column(
                    children: [Text('Not signed in'), SizedBox(height: 8)],
                  ),
                ),
              ),
            )
          : null,
      itemCount: projects.length,
      itemBuilder: (context, index) {
        var project = projects[index];
        return BodyContainer(
          child: ListTile(
            leading: ProjectLeading(project: project),
            trailing: const TrailingArrow(),
            title: Text(project.name.v ?? project.fsId),
            onTap: () async {
              var projectId = project.fsId;
              if (selectMode) {
                Navigator.of(
                  context,
                ).pop(SelectProjectResult(projectId: projectId));
              } else {
                await context.pushPath<void>(
                  projectAccessPath,
                  parameters: {DashboardRouteParams.projectId: projectId},
                );
              }
            },
          ),
        );
      },
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

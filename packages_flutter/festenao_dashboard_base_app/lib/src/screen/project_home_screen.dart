import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/src/provider/festenao_user_projects.dart';
import 'package:festenao_dashboard_base_app/src/provider/route_scope_providers.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_providers.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_images_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_medias_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_home_screen_bloc.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekartik_app_flutter_widget/app_widget.dart';

/// The home screen of a project.
///
/// [projectId] is optional: below a `dashboardProjectScopeRoute` it comes from
/// [currentProjectIdProvider], so the route does not have to read the path
/// parameter and pass it down. Passing it explicitly still works, for the apps
/// that mount this screen outside of a scoped branch.
class DashboardProjectHomeScreen extends ConsumerWidget {
  static const routeName = 'project';
  final String? projectId;
  const DashboardProjectHomeScreen({super.key, this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `watch<String>`: without the explicit type argument the `??` infers
    // its right hand side against the nullable left one, giving a `String?`.
    var currentProjectId =
        projectId ?? ref.watch<String>(currentProjectIdProvider);
    var projectsSdb = ref.watch(rpdUserProjectsDbProvider);
    return BlocProvider(
      blocBuilder: () => ProjectHomeScreenBloc(
        projectsSdb: projectsSdb,
        projectId: currentProjectId,
      ),
      child: _DashboardProjectHomeScreenBody(projectId: currentProjectId),
    );
  }
}

class _DashboardProjectHomeScreenBody extends StatelessWidget {
  final String projectId;
  const _DashboardProjectHomeScreenBody({required this.projectId});

  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<ProjectHomeScreenBloc>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Project $projectId')),
      body: ListView(
        children: [
          ValueStreamBuilder(
            stream: bloc.state,
            builder: (_, snapshot) {
              if (snapshot.hasData) {
                var project = snapshot.data!;
                return Column(
                  children: [
                    ListTile(
                      title: Text(project.name.v ?? '(no name)'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Local project ID: ${project.id}'),
                          Text('Firestore project id: ${project.uid}'),
                        ],
                      ),
                    ),
                    ListTile(
                      title: const Text('Blog demo'),
                      subtitle: const Text('Ids from the route scope'),
                      onTap: () {
                        context.pushPath(
                          blogDemoPath,
                          parameters: {
                            DashboardRouteParams.projectId: projectId,
                          },
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Blog demo (legacy)'),
                      subtitle: const Text('Ids passed as arguments'),
                      onTap: () {
                        context.pushPath(
                          legacyBlogDemoPath,
                          parameters: {
                            DashboardRouteParams.projectId: projectId,
                          },
                        );
                      },
                    ),
                    ListTile(
                      title: const Text(
                        'Content (artist / location / event / image)',
                      ),
                      onTap: () {
                        context.pushPath(
                          contentDemoPath,
                          parameters: {
                            DashboardRouteParams.projectId: projectId,
                          },
                        );
                      },
                    ),

                    ListTile(
                      title: const Text('Content Images'),
                      onTap: () {
                        goToContentImagesScreen(
                          context,
                          projectId: projectId,
                          dataId: SdbProjectContent.defaultDataId,
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Content Medias'),
                      onTap: () {
                        goToContentMediasScreen(
                          context,
                          projectId: projectId,
                          dataId: SdbProjectContent.defaultDataId,
                        );
                      },
                    ),
                  ],
                );
              }
              return const CenteredProgress();
            },
          ),
        ],
      ),
    );
  }
}

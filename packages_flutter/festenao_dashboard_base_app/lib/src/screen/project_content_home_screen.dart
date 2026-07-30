import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/src/provider/festenao_user_projects.dart';
import 'package:festenao_dashboard_base_app/src/provider/route_scope_providers.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_providers.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_images_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_medias_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_home_screen_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekartik_app_flutter_widget/app_widget.dart';

/// The home screen of one data database of a project.
///
/// [projectId] and [dataId] are optional: below a `dashboardProjectScopeRoute`
/// and a `dashboardDataScopeRoute` they come from [currentProjectIdProvider]
/// and [currentDataIdProvider], so the route does not have to read the path
/// parameters and pass them down. Passing them explicitly still works, for the
/// apps that mount this screen outside of a scoped branch.
class DashboardProjectContentHomeScreen extends ConsumerWidget {
  static const routeName = 'project';
  final String? projectId;
  final String? dataId;
  const DashboardProjectContentHomeScreen({
    super.key,
    this.projectId,
    this.dataId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `watch<String>`: without the explicit type argument the `??` infers
    // its right hand side against the nullable left one, giving a `String?`.
    var currentProjectId =
        projectId ?? ref.watch<String>(currentProjectIdProvider);
    var currentDataId = dataId ?? ref.watch<String>(currentDataIdProvider);
    var projectsSdb = ref.watch(rpdUserProjectsDbProvider);
    return BlocProvider(
      blocBuilder: () => ProjectHomeScreenBloc(
        projectsSdb: projectsSdb,
        projectId: currentProjectId,
      ),
      child: _DashboardProjectContentHomeScreenBody(
        projectId: currentProjectId,
        dataId: currentDataId,
      ),
    );
  }
}

class _DashboardProjectContentHomeScreenBody extends ConsumerWidget {
  final String projectId;
  final String dataId;
  const _DashboardProjectContentHomeScreenBody({
    required this.projectId,
    required this.dataId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var bloc = BlocProvider.of<ProjectHomeScreenBloc>(context);
    final sdbContent = ref
        .watch(sdbProjectContentProvider(projectId, dataId))
        .value;
    return Scaffold(
      appBar: AppBar(title: Text('Project $projectId data $dataId')),
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
                    if (sdbContent != null) ...[
                      ListTile(
                        title: const Text('Media source'),
                        subtitle: Text(sdbContent.mediaSource.toString()),
                      ),
                    ],
                    ListTile(
                      title: const Text('Content Images'),
                      onTap: () {
                        goToContentImagesScreen(
                          context,
                          projectId: projectId,
                          dataId: dataId,
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Content Medias'),
                      onTap: () {
                        goToContentMediasScreen(
                          context,
                          projectId: projectId,
                          dataId: dataId,
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

import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/src/provider/festenao_user_projects.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_providers.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_images_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_medias_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_home_screen_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tekartik_app_flutter_widget/app_widget.dart';

class DashboardProjectContentHomeScreen extends ConsumerWidget {
  static const routeName = 'project';
  static const routeLocation = '/project/:project_id';
  static const projectIdPathParameter = 'project_id';
  static String location(String projectId) => '/project/$projectId';
  final String projectId;
  final String dataId;
  const DashboardProjectContentHomeScreen({
    super.key,
    required this.projectId,
    required this.dataId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var projectsSdb = ref.watch(rpdUserProjectsDbProvider);
    return BlocProvider(
      blocBuilder: () =>
          ProjectHomeScreenBloc(projectsSdb: projectsSdb, projectId: projectId),
      child: _DashboardProjectContentHomeScreenBody(
        projectId: projectId,
        dataId: dataId,
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
                        context.push(ContentImagesScreen.location(projectId));
                      },
                    ),
                    ListTile(
                      title: const Text('Content Medias'),
                      onTap: () {
                        context.push(ContentMediasScreen.location(projectId));
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

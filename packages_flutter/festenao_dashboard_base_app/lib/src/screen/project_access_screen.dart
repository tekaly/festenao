import 'package:festenao_dashboard_base_app/src/provider/festenao_user_projects.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_view_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_view_screen_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

class DashboardProjectAccessScreen extends ConsumerWidget {
  static const routeName = 'project_access';
  static const routeLocation = '/project_access/:project_id';
  static const projectIdPathParameter = 'project_id';

  static String location(String projectId) => '/project_access/$projectId';

  final String projectId;

  const DashboardProjectAccessScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var projectsDb = ref.watch(rpdUserProjectsDbProvider);
    return BlocProvider(
      blocBuilder: () => ProjectSdbViewScreenBloc(
        projectsDb: projectsDb,
        projectId: projectId,
      ),
      child: const ProjectViewScreen(),
    );
  }
}

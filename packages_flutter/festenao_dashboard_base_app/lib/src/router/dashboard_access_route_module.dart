import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_access_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/projects_access_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/projects_sdb_screen_bloc.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

/// The project access feature: the list of the projects the user has access to
/// and the access screen of one project.
class DashboardAccessRouteModule implements FeatureRouteModule {
  @override
  String get moduleId => 'dashboard_access';

  @override
  List<RouteBase> get routes => [
    projectsAccessPath.goRoute(
      builder: (context, state) => Consumer(
        builder: (context, ref, child) {
          var projectsDb = ref.watch(rpdUserProjectsDbProvider);
          return BlocProvider(
            blocBuilder: () => ProjectsSdbScreenBloc(projectsDb: projectsDb),
            child: const DashboardProjectsAccessScreen(),
          );
        },
      ),
    ),
    projectAccessPath.goRoute(
      builder: (context, state) => DashboardProjectAccessScreen(
        projectId: state.pathParameter(DashboardRouteParams.projectId),
      ),
    ),
  ];
}

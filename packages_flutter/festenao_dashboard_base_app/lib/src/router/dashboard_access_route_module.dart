import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_access_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_slug_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/projects_access_screen.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';

/// The project access feature: the list of the projects the user has access to,
/// the access screen of one project, and the url of a project (`/p/<slug>`)
/// resolved to it.
///
/// Mounted under the root route rather than at the top level: `/projects_access`
/// opened directly (a fresh page load on the web) then builds the root page
/// below it, so the screen always has somewhere to go back to. A host app whose
/// root route is not named [dashboardHomePath] passes its own
/// [parentRouteName] — the bp app roots its tree on `start`.
class DashboardAccessRouteModule implements NestedFeatureRouteModule {
  @override
  final String parentRouteName;

  /// Creates the module, mounted under [parentRouteName] (the dashboard home
  /// route by default).
  DashboardAccessRouteModule({String? parentRouteName})
    : parentRouteName = parentRouteName ?? dashboardHomePath.name!;

  @override
  String get moduleId => 'dashboard_access';

  @override
  List<RouteBase> get routes => [
    projectsAccessPath.goRoute(
      builder: (context, state) => const DashboardProjectsAccessScreen(),
    ),
    projectAccessPath.goRoute(
      builder: (context, state) => DashboardProjectAccessScreen(
        projectId: state.pathParameter(DashboardRouteParams.projectId),
      ),
    ),
    dashboardProjectSlugPath.goRoute(
      builder: (context, state) => DashboardProjectSlugScreen(
        slug: state.pathParameter(DashboardRouteParams.slug),
        projectLocation: (projectId) => projectAccessPath.location({
          DashboardRouteParams.projectId: projectId,
        }),
      ),
    ),
  ];
}

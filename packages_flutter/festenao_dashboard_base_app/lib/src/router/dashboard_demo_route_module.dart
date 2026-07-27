import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_dashboard_base_app/src/screen/blog_demo_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_demo_screen.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';

/// The demo screens of a project, an independent feature standing for what
/// another package would contribute.
class DashboardDemoRouteModule implements FeatureRouteModule {
  @override
  String get moduleId => 'dashboard_demo';

  @override
  List<RouteBase> get routes => [
    blogDemoPath.goRoute(
      absolute: true,
      builder: (context, state) => BlogDemoScreen(
        projectId: state.pathParameter(DashboardRouteParams.projectId),
      ),
    ),
    contentDemoPath.goRoute(
      absolute: true,
      builder: (context, state) => ContentDemoScreen(
        projectId: state.pathParameter(DashboardRouteParams.projectId),
      ),
    ),
  ];
}

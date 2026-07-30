import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_scope.dart';
import 'package:festenao_dashboard_base_app/src/screen/blog_demo_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_demo_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/legacy_blog_demo_screen.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';

/// The demo screens of a project, an independent feature standing for what
/// another package would contribute.
///
/// [BlogDemoScreen] reads its ids from the scope its route builds,
/// [LegacyBlogDemoScreen] and [ContentDemoScreen] still take them as
/// arguments; the three sit on the same navigator, so a push from the project
/// home pops back to it.
class DashboardDemoRouteModule implements FeatureRouteModule {
  @override
  String get moduleId => 'dashboard_demo';

  @override
  List<RouteBase> get routes => [
    blogDemoPath.goRoute(
      absolute: true,
      builder: (context, state) => dashboardProjectScope(
        state,
        dataId: BlogDemoScreen.blogDataId,
        child: const BlogDemoScreen(),
      ),
    ),
    legacyBlogDemoPath.goRoute(
      absolute: true,
      builder: (context, state) => LegacyBlogDemoScreen(
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

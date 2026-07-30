import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_scope.dart';
import 'package:festenao_dashboard_base_app/src/screen/blog_demo_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_demo_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/legacy_blog_demo_screen.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';

/// The demo screens of a project, an independent feature standing for what
/// another package would contribute.
///
/// Mounted under [dashboardProjectPath] rather than at the top level, so
/// `/project/x/blog_demo` opened directly builds its whole ancestor stack and
/// the project screen is one back away — the resolver does the mounting, this
/// module still knows nothing of the one declaring the project route.
///
/// [BlogDemoScreen] reads its ids from the scope its route builds,
/// [LegacyBlogDemoScreen] and [ContentDemoScreen] still take them as
/// arguments.
class DashboardDemoRouteModule implements NestedFeatureRouteModule {
  @override
  String get moduleId => 'dashboard_demo';

  @override
  String get parentRouteName => dashboardProjectPath.name!;

  @override
  List<RouteBase> get routes => [
    blogDemoPath.goRoute(
      builder: (context, state) => dashboardProjectScope(
        state,
        dataId: BlogDemoScreen.blogDataId,
        child: const BlogDemoScreen(),
      ),
    ),
    legacyBlogDemoPath.goRoute(
      builder: (context, state) => LegacyBlogDemoScreen(
        projectId: state.pathParameter(DashboardRouteParams.projectId),
      ),
    ),
    contentDemoPath.goRoute(
      builder: (context, state) => ContentDemoScreen(
        projectId: state.pathParameter(DashboardRouteParams.projectId),
      ),
    ),
  ];
}

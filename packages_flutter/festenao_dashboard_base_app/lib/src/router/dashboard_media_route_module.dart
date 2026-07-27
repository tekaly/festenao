import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_media_edit_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_media_screen.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';

/// The media feature: viewing, editing and creating a media of a project data.
///
/// Its definitions live below [dashboardProjectDataPath], but the routes are
/// mounted at the top level ([RoutePathDefGoRouteExt.goRoute] with `absolute`),
/// the way they historically were: the data level of the tree has no shared
/// layout to sit under.
class DashboardMediaRouteModule implements FeatureRouteModule {
  @override
  String get moduleId => 'dashboard_media';

  @override
  List<RouteBase> get routes => [
    contentMediaPath.goRoute(
      absolute: true,
      builder: (context, state) => ContentMediaScreen(
        projectId: state.pathParameter(DashboardRouteParams.projectId),
        dataId: state.pathParameter(DashboardRouteParams.dataId),
        mediaId: state.pathParameter(DashboardRouteParams.mediaId),
      ),
    ),
    contentMediaEditPath.goRoute(
      absolute: true,
      builder: (context, state) => ContentMediaEditScreen(
        projectId: state.pathParameter(DashboardRouteParams.projectId),
        dataId: state.pathParameter(DashboardRouteParams.dataId),
        mediaId: state.pathParameter(DashboardRouteParams.mediaId),
      ),
    ),
    contentMediaCreatePath.goRoute(
      absolute: true,
      builder: (context, state) => ContentMediaEditScreen(
        projectId: state.pathParameter(DashboardRouteParams.projectId),
        dataId: state.pathParameter(DashboardRouteParams.dataId),
        mediaId: null,
      ),
    ),
  ];
}

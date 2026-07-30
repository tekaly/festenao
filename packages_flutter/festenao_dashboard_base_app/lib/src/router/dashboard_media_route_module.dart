import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_media_edit_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_media_screen.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';

/// The media feature: viewing, editing and creating a media of a project data.
///
/// Its definitions live below [dashboardProjectDataPath] and so do its routes:
/// the resolver mounts them there, so a media location opened directly builds
/// its ancestor stack instead of standing alone.
class DashboardMediaRouteModule implements NestedFeatureRouteModule {
  @override
  String get moduleId => 'dashboard_media';

  @override
  String get parentRouteName => dashboardProjectDataPath.name!;

  @override
  List<RouteBase> get routes => [
    contentMediaPath.goRoute(
      builder: (context, state) => ContentMediaScreen(
        projectId: state.pathParameter(DashboardRouteParams.projectId),
        dataId: state.pathParameter(DashboardRouteParams.dataId),
        mediaId: state.pathParameter(DashboardRouteParams.mediaId),
      ),
    ),
    contentMediaEditPath.goRoute(
      builder: (context, state) => ContentMediaEditScreen(
        projectId: state.pathParameter(DashboardRouteParams.projectId),
        dataId: state.pathParameter(DashboardRouteParams.dataId),
        mediaId: state.pathParameter(DashboardRouteParams.mediaId),
      ),
    ),
    contentMediaCreatePath.goRoute(
      builder: (context, state) => ContentMediaEditScreen(
        projectId: state.pathParameter(DashboardRouteParams.projectId),
        dataId: state.pathParameter(DashboardRouteParams.dataId),
        mediaId: null,
      ),
    ),
  ];
}

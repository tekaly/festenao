import 'package:festenao_dashboard_base_app/src/router/dashboard_router.dart';
import 'package:festenao_dashboard_base_app/src/screen/blog_demo_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_demo_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_image_edit_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_image_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_images_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_media_edit_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_media_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_medias_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/home_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/legacy_blog_demo_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_access_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_home_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/projects_access_screen.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';

/// The path parameter names of the dashboard routes.
///
/// They alias the [DashboardRouter] constants, so a host app, the reusable
/// screens and the route definitions never disagree on a parameter name.
class DashboardRouteParams {
  /// `project_id`
  static const projectId = DashboardRouter.projectIdParam;

  /// `data_id`
  static const dataId = DashboardRouter.dataIdParam;

  /// `image_id`
  static const imageId = DashboardRouter.imageIdParam;

  /// `media_id`
  static const mediaId = ContentMediaScreen.mediaIdPathParameter;
}

/// `/`, the root of the dashboard.
final dashboardHomePath = RoutePathDef.parse(
  DashboardHomePage.routeLocation,
  name: DashboardHomePage.routeName,
);

/// `/project/:project_id`
final dashboardProjectPath = dashboardHomePath.child(
  DashboardRouter.projectLocationPathPart,
  name: DashboardProjectHomeScreen.routeName,
);

/// `/project/:project_id/data/:data_id`
final dashboardProjectDataPath = dashboardProjectPath.child(
  DashboardRouter.dataPath,
  name: 'project_data',
);

/// `/project/:project_id/data/:data_id/images`
final contentImagesPath = dashboardProjectDataPath.child(
  ContentImagesScreen.routeLocationPart,
  name: ContentImagesScreen.routeName,
);

/// `/project/:project_id/data/:data_id/medias`
final contentMediasPath = dashboardProjectDataPath.child(
  ContentMediasScreen.routeLocationPart,
  name: ContentMediasScreen.routeName,
);

/// `/project/:project_id/data/:data_id/image_create`
final contentImageCreatePath = dashboardProjectDataPath.child(
  ContentImageEditScreen.createRouteLocationPart,
  name: ContentImageEditScreen.createRouteName,
);

/// `/project/:project_id/data/:data_id/image/:image_id`, an intermediate level
/// with no screen of its own.
final contentImageRootPath = dashboardProjectDataPath.child(
  DashboardRouter.imagePath,
);

/// `/project/:project_id/data/:data_id/image/:image_id/view`
final contentImagePath = contentImageRootPath.child(
  ContentImageScreen.routeLocationPart,
  name: ContentImageScreen.routeName,
);

/// `/project/:project_id/data/:data_id/image/:image_id/edit`
final contentImageEditPath = contentImageRootPath.child(
  ContentImageEditScreen.editRouteLocationPart,
  name: ContentImageEditScreen.editRouteName,
);

/// `/project/:project_id/data/:data_id/media/:media_id`
final contentMediaPath = dashboardProjectDataPath.child(
  'media/:${DashboardRouteParams.mediaId}',
  name: ContentMediaScreen.routeName,
);

/// `/project/:project_id/data/:data_id/media_edit/:media_id`
final contentMediaEditPath = dashboardProjectDataPath.child(
  'media_edit/:${DashboardRouteParams.mediaId}',
  name: ContentMediaEditScreen.editRouteName,
);

/// `/project/:project_id/data/:data_id/media_create`
final contentMediaCreatePath = dashboardProjectDataPath.child(
  'media_create',
  name: ContentMediaEditScreen.createRouteName,
);

/// `/project/:project_id/blog_demo`
final blogDemoPath = dashboardProjectPath.child(
  BlogDemoScreen.routeLocationPart,
  name: BlogDemoScreen.routeName,
);

/// `/project/:project_id/legacy_blog_demo`
final legacyBlogDemoPath = dashboardProjectPath.child(
  LegacyBlogDemoScreen.routeLocationPart,
  name: LegacyBlogDemoScreen.routeName,
);

/// `/project/:project_id/content_demo`
final contentDemoPath = dashboardProjectPath.child(
  ContentDemoScreen.routeLocationPart,
  name: ContentDemoScreen.routeName,
);

/// `/projects_access`
final projectsAccessPath = RoutePathDef.parse(
  DashboardProjectsAccessScreen.routeLocation,
  name: DashboardProjectsAccessScreen.routeName,
);

/// `/project_access/:project_id`
final projectAccessPath = RoutePathDef.parse(
  DashboardProjectAccessScreen.routeLocation,
  name: DashboardProjectAccessScreen.routeName,
);

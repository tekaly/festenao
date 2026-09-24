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

  /// `question_id`
  static const questionId = 'question_id';

  /// `quiz_id`
  static const quizId = 'quiz_id';

  /// `slug`, the url of a project (`/p/:slug`).
  static const slug = 'slug';
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
///
/// A child of [dashboardHomePath], so the route hangs under `/` and a location
/// opened directly (a fresh page load on the web) builds the home page below
/// it: there is always a way back to the root.
final projectsAccessPath = dashboardHomePath.child(
  DashboardProjectsAccessScreen.routeLocation,
  name: DashboardProjectsAccessScreen.routeName,
);

/// `/project_access/:project_id`, a child of [dashboardHomePath] for the same
/// reason as [projectsAccessPath].
final projectAccessPath = dashboardHomePath.child(
  DashboardProjectAccessScreen.routeLocation,
  name: DashboardProjectAccessScreen.routeName,
);

/// `/p/:slug`, the url of a project, resolved to its access screen; a child
/// of [dashboardHomePath] for the same reason as [projectsAccessPath].
final dashboardProjectSlugPath = dashboardHomePath.child(
  'p/:${DashboardRouteParams.slug}',
  name: 'project_slug',
);

/// `/logs`, a child of [dashboardHomePath] for the same reason as
/// [projectsAccessPath].
final dashboardLogsPath = dashboardHomePath.child(
  'logs',
  name: 'dashboard_logs',
);

/// `/project/:project_id/quizz`, the quizz home of a project (questions and
/// quizzes).
final quizzHomePath = dashboardProjectPath.child('quizz', name: 'quizz');

/// `/project/:project_id/quizz/question_create`
final quizzQuestionCreatePath = quizzHomePath.child(
  'question_create',
  name: 'quizz_question_create',
);

/// `/project/:project_id/quizz/question/:question_id`
final quizzQuestionEditPath = quizzHomePath.child(
  'question/:${DashboardRouteParams.questionId}',
  name: 'quizz_question_edit',
);

/// `/project/:project_id/quizz/quiz/:quiz_id`, the admin control of a quiz.
final quizzControlPath = quizzHomePath.child(
  'quiz/:${DashboardRouteParams.quizId}',
  name: 'quizz_control',
);

/// `/project/:project_id/quizz/quiz/:quiz_id/tv`, the tv display of a quiz.
final quizzTvPath = quizzControlPath.child('tv', name: 'quizz_tv');

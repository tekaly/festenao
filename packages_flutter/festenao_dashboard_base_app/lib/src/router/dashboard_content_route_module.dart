import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_scope.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_image_edit_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_image_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_images_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_medias_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/home_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_content_home_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_home_screen.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';

/// The main dashboard tree: `/`, then everything under
/// `/project/:project_id/data/:data_id`.
///
/// Every route is declared from its [RoutePathDef], so a nested [GoRoute] gets
/// its relative path and its name from the definition and no location is ever
/// concatenated by hand.
class DashboardContentRouteModule implements FeatureRouteModule {
  @override
  String get moduleId => 'dashboard_content';

  @override
  List<RouteBase> get routes => [
    dashboardHomePath.goRoute(
      builder: (context, state) => const DashboardHomePage(),
      routes: [
        // The project screens read their ids from riverpod; each route builds
        // the scope that holds them (a plain ProviderScope, so every page stays
        // on the same navigator — see `dashboard_route_scope.dart`).
        dashboardProjectPath.goRoute(
          builder: (context, state) => dashboardProjectScope(
            state,
            child: const DashboardProjectHomeScreen(),
          ),
          routes: [
            dashboardProjectDataPath.goRoute(
              builder: (context, state) => dashboardProjectScope(
                state,
                child: const DashboardProjectContentHomeScreen(),
              ),
              routes: [
                contentImagesPath.goRoute(
                  builder: (context, state) => ContentImagesScreen(
                    projectId: state.pathParameter(
                      DashboardRouteParams.projectId,
                    ),
                    dataId: state.pathParameter(DashboardRouteParams.dataId),
                  ),
                ),
                contentMediasPath.goRoute(
                  builder: (context, state) => ContentMediasScreen(
                    projectId: state.pathParameter(
                      DashboardRouteParams.projectId,
                    ),
                    dataId: state.pathParameter(DashboardRouteParams.dataId),
                  ),
                ),
                contentImageCreatePath.goRoute(
                  builder: (context, state) => ContentImageEditScreen(
                    projectId: state.pathParameter(
                      DashboardRouteParams.projectId,
                    ),
                    dataId: state.pathParameter(DashboardRouteParams.dataId),
                    imageId: null,
                  ),
                ),
                contentImageRootPath.goRoute(
                  // No screen of its own, only a parameter level.
                  builder: (context, state) => _unknownScreen(state),
                  routes: [
                    contentImagePath.goRoute(
                      builder: (context, state) => ContentImageScreen(
                        projectId: state.pathParameter(
                          DashboardRouteParams.projectId,
                        ),
                        dataId: state.pathParameter(
                          DashboardRouteParams.dataId,
                        ),
                        imageId: state.pathParameter(
                          DashboardRouteParams.imageId,
                        ),
                      ),
                    ),
                    contentImageEditPath.goRoute(
                      builder: (context, state) => ContentImageEditScreen(
                        projectId: state.pathParameter(
                          DashboardRouteParams.projectId,
                        ),
                        dataId: state.pathParameter(
                          DashboardRouteParams.dataId,
                        ),
                        imageId: state.pathParameter(
                          DashboardRouteParams.imageId,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}

Widget _unknownScreen(GoRouterState state) => Scaffold(
  appBar: AppBar(title: const Text('Unknown')),
  body: Text('${state.uri}'),
);

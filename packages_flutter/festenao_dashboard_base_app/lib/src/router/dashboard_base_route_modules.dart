import 'package:festenao_dashboard_base_app/src/router/dashboard_access_route_module.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_content_route_module.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_demo_route_module.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_media_route_module.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';

/// The route modules contributed by this package, in the order they should
/// appear in a host app.
///
/// A host app passes them to [ModularRouteResolver.assembleRoutes] and adds its
/// own modules and overrides on top; taking the list apart is fine when an app
/// only wants some of the features.
List<FeatureRouteModule> dashboardBaseRouteModules() => [
  DashboardContentRouteModule(),
  DashboardAccessRouteModule(),
  DashboardMediaRouteModule(),
  DashboardDemoRouteModule(),
];

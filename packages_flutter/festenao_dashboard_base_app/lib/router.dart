/// Routing helpers for the festenao dashboard base app.
///
/// The screens of this package are exposed as `FeatureRouteModule`s built on
/// `festenao_navigator_flutter`: a host app assembles
/// [dashboardBaseRouteModules] with its own modules and overrides, and
/// navigates to the `RoutePathDef`s exported here rather than to hand written
/// locations.
library;

export 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';

export 'src/router/content_navigator_go_router_bridge.dart';
export 'src/router/dashboard_access_route_module.dart';
export 'src/router/dashboard_base_route_modules.dart';
export 'src/router/dashboard_content_route_module.dart';
export 'src/router/dashboard_demo_route_module.dart';
export 'src/router/dashboard_media_route_module.dart';
export 'src/router/dashboard_route_paths.dart';
export 'src/router/dashboard_route_scope.dart';
export 'src/router/dashboard_router.dart';

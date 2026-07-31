import 'package:festenao_common_flutter/log/log.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';

/// Route module introducing top-level log viewing and playground screen.
class DashboardLogRouteModule implements FeatureRouteModule {
  @override
  String get moduleId => 'dashboard_log';

  @override
  List<RouteBase> get routes => [
    dashboardLogsPath.goRoute(
      builder: (context, state) => const FestenaoLogScreen(),
    ),
  ];
}

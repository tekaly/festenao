import 'package:festenao_common_flutter/log/log.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';

/// The log viewing and playground screen.
///
/// Mounted under the root route rather than at the top level, so `/logs`
/// opened directly builds the root page below it and always has somewhere to
/// go back to. A host app whose root route is not named [dashboardHomePath]
/// passes its own [parentRouteName].
class DashboardLogRouteModule implements NestedFeatureRouteModule {
  @override
  final String parentRouteName;

  /// Creates the module, mounted under [parentRouteName] (the dashboard home
  /// route by default).
  DashboardLogRouteModule({String? parentRouteName})
    : parentRouteName = parentRouteName ?? dashboardHomePath.name!;

  @override
  String get moduleId => 'dashboard_log';

  @override
  List<RouteBase> get routes => [
    dashboardLogsPath.goRoute(
      builder: (context, state) => const FestenaoLogScreen(),
    ),
  ];
}

import 'package:go_router/go_router.dart';

import 'feature_route_module.dart';

/// True when [route] is the base route that [override] replaces.
///
/// Matching precedence, deliberately deterministic:
/// 1. when **both** routes are named, the names must be equal (a name never
///    matches a different name, even on the same path);
/// 2. otherwise the [GoRoute.path] must be exactly equal.
///
/// Only [GoRoute]s take part in matching: a [ShellRoute] has no identity of
/// its own, override the routes it wraps instead.
bool routeMatchesOverride(RouteBase route, RouteBase override) {
  if (route is! GoRoute || override is! GoRoute) {
    return false;
  }
  var routeName = route.name;
  var overrideName = override.name;
  if (routeName != null && overrideName != null) {
    return routeName == overrideName;
  }
  return route.path == override.path;
}

/// Assembles the route tree of an application from its feature packages,
/// applying the application's own overrides on top.
///
/// Resolution is synchronous and meant to run once, during app
/// initialization.
class ModularRouteResolver {
  /// Merges the [baseModules] routes, in module order, then applies
  /// [customOverrides].
  ///
  /// An override that matches a base route (see [routeMatchesOverride])
  /// replaces it **in place**, so the surrounding order and the nesting of the
  /// other routes are preserved; an override matching nothing is appended,
  /// which is how an app adds its own routes to the tree.
  ///
  /// Throws an [ArgumentError] when two modules share a [FeatureRouteModule
  /// .moduleId], which is always a wiring mistake.
  static List<RouteBase> assembleRoutes({
    required List<FeatureRouteModule> baseModules,
    List<RouteBase> customOverrides = const [],
  }) {
    var moduleIds = <String>{};
    var mergedRoutes = <RouteBase>[];
    for (var module in baseModules) {
      if (!moduleIds.add(module.moduleId)) {
        throw ArgumentError.value(
          baseModules,
          'baseModules',
          'duplicated module id \'${module.moduleId}\'',
        );
      }
      mergedRoutes.addAll(module.routes);
    }

    for (var overrideRoute in customOverrides) {
      var index = mergedRoutes.indexWhere(
        (base) => routeMatchesOverride(base, overrideRoute),
      );
      if (index >= 0) {
        mergedRoutes[index] = overrideRoute;
      } else {
        mergedRoutes.add(overrideRoute);
      }
    }

    return mergedRoutes;
  }
}

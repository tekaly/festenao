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

/// A copy of [route] whose sub-routes are [routes].
///
/// [GoRoute] is immutable, so mounting a module under an existing route means
/// rebuilding that route with the extra children.
GoRoute _routeWithSubRoutes(GoRoute route, List<RouteBase> routes) {
  return GoRoute(
    path: route.path,
    name: route.name,
    builder: route.builder,
    pageBuilder: route.pageBuilder,
    parentNavigatorKey: route.parentNavigatorKey,
    redirect: route.redirect,
    onExit: route.onExit,
    caseSensitive: route.caseSensitive,
    routes: routes,
  );
}

/// A copy of the [ShellRoute] [route] whose sub-routes are [routes].
///
/// Only the plain [ShellRoute] is rebuilt: the stateful shells carry branch
/// state a blind copy would lose, so mounting into one is refused rather than
/// done wrong.
RouteBase _shellWithRoutes(RouteBase route, List<RouteBase> routes) {
  if (route is ShellRoute) {
    return ShellRoute(
      builder: route.builder,
      pageBuilder: route.pageBuilder,
      observers: route.observers,
      navigatorKey: route.navigatorKey,
      parentNavigatorKey: route.parentNavigatorKey,
      redirect: route.redirect,
      restorationScopeId: route.restorationScopeId,
      routes: routes,
    );
  }
  throw ArgumentError.value(
    route,
    'route',
    'cannot mount routes under a ${route.runtimeType}',
  );
}

/// A copy of [route] whose sub-routes are [routes], whichever kind it is.
RouteBase _withSubRoutes(RouteBase route, List<RouteBase> routes) =>
    route is GoRoute
    ? _routeWithSubRoutes(route, routes)
    : _shellWithRoutes(route, routes);

/// A copy of [routes] with [subRoutes] appended to the children of the
/// [GoRoute] named [parentRouteName], or null when no route carries that name.
///
/// The whole tree is searched, sub-routes and shells included.
List<RouteBase>? _mountUnder(
  List<RouteBase> routes,
  String parentRouteName,
  List<RouteBase> subRoutes,
) {
  var found = false;
  var result = <RouteBase>[];
  for (var route in routes) {
    if (found) {
      result.add(route);
      continue;
    }
    if (route is GoRoute && route.name == parentRouteName) {
      found = true;
      result.add(_routeWithSubRoutes(route, [...route.routes, ...subRoutes]));
      continue;
    }
    var childResult = _mountUnder(route.routes, parentRouteName, subRoutes);
    if (childResult == null) {
      result.add(route);
      continue;
    }
    found = true;
    result.add(_withSubRoutes(route, childResult));
  }
  return found ? result : null;
}

/// A copy of [routes] where the first route matching [override] is replaced by
/// it, or null when nothing matches.
///
/// The whole tree is searched, so an app can replace a screen a module
/// contributed deep in a branch (white labeling), not only a top level one.
List<RouteBase>? _applyOverride(List<RouteBase> routes, RouteBase override) {
  var found = false;
  var result = <RouteBase>[];
  for (var route in routes) {
    if (found) {
      result.add(route);
      continue;
    }
    if (routeMatchesOverride(route, override)) {
      found = true;
      result.add(override);
      continue;
    }
    var childResult = _applyOverride(route.routes, override);
    if (childResult == null) {
      result.add(route);
      continue;
    }
    found = true;
    result.add(_withSubRoutes(route, childResult));
  }
  return found ? result : null;
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
  /// A plain [FeatureRouteModule] contributes its routes at the top level; a
  /// [NestedFeatureRouteModule] has them mounted under the route named by its
  /// [NestedFeatureRouteModule.parentRouteName], whichever module declared it.
  /// Nesting happens once every top level module has contributed, so the order
  /// of the modules in [baseModules] does not matter for it.
  ///
  /// An override that matches a route (see [routeMatchesOverride]) replaces it
  /// **in place** anywhere in the tree, so the surrounding order and the
  /// nesting of the other routes are preserved; an override matching nothing is
  /// appended at the top level, which is how an app adds its own routes.
  ///
  /// Throws an [ArgumentError] when two modules share a
  /// [FeatureRouteModule.moduleId], or when a nested module names a parent
  /// route no module declares — both are wiring mistakes.
  static List<RouteBase> assembleRoutes({
    required List<FeatureRouteModule> baseModules,
    List<RouteBase> customOverrides = const [],
  }) {
    var moduleIds = <String>{};
    var mergedRoutes = <RouteBase>[];
    var nestedModules = <NestedFeatureRouteModule>[];
    for (var module in baseModules) {
      if (!moduleIds.add(module.moduleId)) {
        throw ArgumentError.value(
          baseModules,
          'baseModules',
          'duplicated module id \'${module.moduleId}\'',
        );
      }
      if (module is NestedFeatureRouteModule) {
        nestedModules.add(module);
      } else {
        mergedRoutes.addAll(module.routes);
      }
    }

    for (var module in nestedModules) {
      var mounted = _mountUnder(
        mergedRoutes,
        module.parentRouteName,
        module.routes,
      );
      if (mounted == null) {
        throw ArgumentError.value(
          baseModules,
          'baseModules',
          'module \'${module.moduleId}\' hangs from the route '
              '\'${module.parentRouteName}\', which no module declares',
        );
      }
      mergedRoutes = mounted;
    }

    for (var overrideRoute in customOverrides) {
      mergedRoutes =
          _applyOverride(mergedRoutes, overrideRoute) ??
          [...mergedRoutes, overrideRoute];
    }

    return mergedRoutes;
  }
}

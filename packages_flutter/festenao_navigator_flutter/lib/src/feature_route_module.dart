import 'package:go_router/go_router.dart';

/// The contract a feature package implements to expose its screens to a host
/// application without knowing anything about that application's route tree.
///
/// A feature package must not import another feature package nor hardcode a
/// cross-package location: it declares its own [routes] and exposes its
/// `RoutePathDef`s (and hence its path parameter names) publicly so the host
/// app can navigate to them.
abstract class FeatureRouteModule {
  /// A stable identifier, unique in a given app (`school`, `auth`, ...).
  ///
  /// Used to report duplicates and to look a module up in a list.
  String get moduleId;

  /// The routes contributed by this module, in the order they should appear.
  List<RouteBase> get routes;
}

/// A [FeatureRouteModule] whose routes are mounted **under** an existing route
/// of the assembled tree rather than at the top level.
///
/// This is how a feature package contributes a screen that belongs inside
/// another module's branch — the blog demo of a project living at
/// `/project/:project_id/blog_demo` — without either module importing the
/// other: it names the parent route, and [ModularRouteResolver] does the
/// mounting.
///
/// It matters beyond tidiness: a route mounted at the top level has no parent
/// page, so opening it directly (a fresh page load on the web) gives a single
/// page with nothing to go back to. Nested, the same location builds its whole
/// ancestor stack.
abstract class NestedFeatureRouteModule implements FeatureRouteModule {
  /// The [GoRoute.name] of the route this module's [routes] hang from.
  ///
  /// Resolution fails loudly when no route of the assembled tree carries that
  /// name: a module contributing to a branch that does not exist is a wiring
  /// mistake, not something to silently drop.
  String get parentRouteName;
}

/// A [FeatureRouteModule] built from a plain list of routes, for modules with
/// no state of their own.
class FeatureRouteModuleBase implements FeatureRouteModule {
  @override
  final String moduleId;

  @override
  final List<RouteBase> routes;

  /// Creates a module contributing [routes].
  FeatureRouteModuleBase({required this.moduleId, required this.routes});

  @override
  String toString() => 'FeatureRouteModule($moduleId, ${routes.length} routes)';
}

/// Module list helpers.
extension FeatureRouteModuleListExt on List<FeatureRouteModule> {
  /// The module with [moduleId], or null.
  FeatureRouteModule? findModuleOrNull(String moduleId) {
    for (var module in this) {
      if (module.moduleId == moduleId) {
        return module;
      }
    }
    return null;
  }
}

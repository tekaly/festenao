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

/// Modular, type safe and scoped navigation for Festenao apps, on top of
/// go_router and riverpod.
///
/// - [FeatureRouteModule]: the contract a feature package implements to
///   contribute its routes without knowing the host app;
/// - [ModularRouteResolver]: merges those modules and applies the app's own
///   overrides (white labeling, feature flags);
/// - [RoutePathDef]: declared route paths, relative paths and parameter
///   inheritance, without string concatenation;
/// - [providerScopeShellRoute]: a [ShellRoute] whose children share a
///   `ProviderScope` configured from the active route.
///
/// go_router is re-exported so an app only imports this facade.
library;

export 'package:go_router/go_router.dart';

export 'src/feature_route_module.dart';
export 'src/modular_route_resolver.dart';
export 'src/navigator_ext.dart';
export 'src/route_location.dart';
export 'src/route_path.dart';
export 'src/route_up_button.dart';
export 'src/scoped_shell_route.dart';

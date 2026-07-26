import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod/misc.dart' show Override;

/// Builds the riverpod overrides of a scoped shell route from the active
/// route state (typically from its path parameters).
typedef ScopedShellOverrides = List<Override> Function(GoRouterState state);

/// Builds the layout shared by the children of a scoped shell route. It is
/// built **inside** the scope, so it can read the overridden providers.
typedef ScopedShellBuilder =
    Widget Function(BuildContext context, GoRouterState state, Widget child);

/// Builds the identity of a scope: when the returned value changes, the whole
/// [ProviderScope] (and every provider it holds) is disposed and recreated.
typedef ScopedShellKeyBuilder = Object? Function(GoRouterState state);

/// A [ShellRoute] whose children all live under a [ProviderScope] configured
/// from the active route.
///
/// This is how a branch of the route tree gets its own scoped state without
/// every screen wrapping itself: the overrides are derived from the route
/// (usually a path parameter), the children read them as plain providers, and
/// leaving the branch disposes the scope.
///
/// ```dart
/// providerScopeShellRoute(
///   overrides: (state) => [
///     currentSchoolIdProvider.overrideWithValue(state.pathParameter('school_id')),
///   ],
///   scopeKey: (state) => state.pathParameters['school_id'],
///   builder: (context, state, child) => SchoolShellLayout(child: child),
///   routes: [...],
/// )
/// ```
///
/// Only the providers listed in [overrides] are scoped: a provider derived
/// from one of them must declare it in its own `dependencies`
/// (`@Riverpod(dependencies: [currentSchoolId])` with riverpod_generator) or
/// it is created in the root container, where the override does not exist.
///
/// [scopeKey] is optional but matters: without it, navigating from
/// `/school/124/...` to `/school/125/...` keeps the same scope and only
/// updates the overridden values (cheap, but any state cached in a scoped
/// provider survives the school change). Returning the school id from
/// [scopeKey] recreates the scope instead, disposing everything scoped to the
/// previous school.
ShellRoute providerScopeShellRoute({
  required ScopedShellOverrides overrides,
  required List<RouteBase> routes,
  ScopedShellBuilder? builder,
  ScopedShellKeyBuilder? scopeKey,
  GlobalKey<NavigatorState>? navigatorKey,
  GlobalKey<NavigatorState>? parentNavigatorKey,
  List<NavigatorObserver>? observers,
  String? restorationScopeId,
}) {
  return ShellRoute(
    navigatorKey: navigatorKey,
    parentNavigatorKey: parentNavigatorKey,
    observers: observers,
    restorationScopeId: restorationScopeId,
    routes: routes,
    builder: (context, state, child) {
      return ProviderScope(
        key: scopeKey == null ? null : ValueKey(scopeKey(state)),
        overrides: overrides(state),
        child: builder == null
            ? child
            : Builder(builder: (context) => builder(context, state, child)),
      );
    },
  );
}

/// Re-exposes the riverpod scope of [context] to [child].
///
/// A route pushed on the **root** navigator (a full screen modal with
/// `parentNavigatorKey: rootNavigatorKey`) is built outside of the shell
/// subtree, so it does not see the scope created by
/// [providerScopeShellRoute]. Wrapping the pushed screen with this keeps the
/// scoped providers readable:
///
/// ```dart
/// showDialog(
///   context: context,
///   builder: (_) => scopedFrom(context, child: const StudentEditDialog()),
/// );
/// ```
///
/// The container is not owned here: it stays alive (and gets disposed) with
/// the shell that created it.
Widget scopedFrom(BuildContext context, {required Widget child}) {
  return UncontrolledProviderScope(
    container: ProviderScope.containerOf(context, listen: false),
    child: child,
  );
}

# Product Requirement Document (PRD): Modular & Scoped Flutter Navigation Architecture

---

## 1. Executive Summary

As Flutter applications scale into multi-package monorepos, traditional monolithic routing leads to tight coupling, white-labeling friction, and fragile state management.

This document defines the technical product requirements for a **Modular, Type-Safe, and Scoped Navigation Framework** combining **GoRouter** and **Riverpod**. The system provides contract-driven route registration across decoupled feature packages, dynamic route overrides for white-labeling, and automated `ProviderScope` inheritance across nested shell routes.

---

## 2. Core Vision & System Architecture

```
[ Root GoRouter Config (App Shell) ]
                │
   ┌────────────┴────────────┐
   ▼                         ▼
[ Package A: Auth ]     [ Package B: Dashboard ]
 (Base Feature Module)    (Base Feature Module)
   │                         │
   └───────────┬─────────────┘
               ▼
[ ModularRouteResolver ] ──◄── [ App Overrides (Custom Client UI) ]
               │
               ▼
   [ Assembled Route Tree ]
               │
   ┌───────────┴───────────┐
   ▼                       ▼
(ShellRoute A)          (ShellRoute B)
   │                       │
 ┌─┴─────────────────┐   ┌─┴─────────────────┐
 │ Scoped Provider 1 │   │ Scoped Provider 2 │
 └─┬───────────────┬─┘   └─┬───────────────┬─┘
   ▼               ▼       ▼               ▼
(Child Route 1) (Child 2) (Child Route 3) (Child 4)

```

---

## 3. Product Features & Requirements

### Feature 1: Feature Package Isolation & Contract (`FeatureRouteModule`)

Feature packages must expose their internal screens without importing other feature packages or knowing about the root application's routing state.

#### Requirements:

* Define a lightweight abstract contract `FeatureRouteModule` in the `core_navigation` package.
* Each feature package must implement this contract to declare its base `RouteBase` definitions.
* Packages must expose path parameters explicitly without hardcoding cross-package navigation URLs.

```dart
// core_navigation/lib/src/feature_route_module.dart
import 'package:go_router/go_router.dart';

abstract class FeatureRouteModule {
  String get moduleId;
  List<RouteBase> get routes;
}

```

---

### Feature 2: Route Override Engine (`ModularRouteResolver`)

The system must allow target application entry points to replace base routes provided by feature packages—enabling white-labeling, custom client flows, or feature-flagged routes.

#### Requirements:

* Provide a deterministic resolution algorithm that compares custom overrides against base package routes.
* Matching criteria must support both route **Name** (`GoRoute.name`) and exact **Path** (`GoRoute.path`).
* Overridden routes replace base definitions in place while maintaining surrounding nested structures.

```dart
// core_navigation/lib/src/modular_route_resolver.dart
import 'package:go_router/go_router.dart';
import 'feature_route_module.dart';

class ModularRouteResolver {
  static List<RouteBase> assembleRoutes({
    required List<FeatureRouteModule> baseModules,
    List<RouteBase> customOverrides = const [],
  }) {
    final List<RouteBase> mergedRoutes = [];

    for (final module in baseModules) {
      mergedRoutes.addAll(module.routes);
    }

    for (final overrideRoute in customOverrides) {
      if (overrideRoute is GoRoute) {
        mergedRoutes.removeWhere((base) {
          if (base is GoRoute) {
            return (base.name != null && base.name == overrideRoute.name) ||
                   base.path == overrideRoute.path;
          }
          return false;
        });
      }
      mergedRoutes.add(overrideRoute);
    }

    return mergedRoutes;
  }
}

```

---

### Feature 3: Type-Safe Navigation & Relative Jumps

To prevent string-concatenation errors across nested routes, the system must enforce type safety and parameter-driven relative navigation.

#### Requirements:

* Support type-safe route definitions using standard `go_router_builder` constructs.
* Provide clean mechanisms to jump sideways or deeper within a route tree without manual parent path parsing.
* Inherit path parameters (`:userId`, `:dashboardId`) automatically across child route transitions.

```dart
// Navigating relative to active context location
void navigateToSibling(BuildContext context, String targetSegment) {
  final currentUri = GoRouterState.of(context).uri;
  final segments = List<String>.from(currentUri.pathSegments);
  
  if (segments.isNotEmpty) {
    segments[segments.length - 1] = targetSegment;
  }

  context.go(Uri(pathSegments: segments).toString());
}

```

---

### Feature 4: Automatic Shell-Level Provider Scoping

Child routes operating under a shared layout (such as a tab view, navigation drawer, or master-detail layout) must inherit scoped Riverpod state that cleans up automatically when leaving the branch.

#### Requirements:

* Inject a `ProviderScope` directly inside `ShellRoute.builder`.
* Child routes under the shell must seamlessly read overridden values without manually wrapping individual screens.
* Disposing/exiting the `ShellRoute` branch must automatically dispose of the scoped `ProviderContainer`.

```dart
// ShellRoute definition with branch-level ProviderScope
ShellRoute(
  builder: (context, state, child) {
    final dashboardId = state.pathParameters['dashboardId'] ?? 'default';

    return ProviderScope(
      overrides: [
        currentDashboardIdProvider.overrideWithValue(dashboardId),
      ],
      child: AppShellLayout(child: child),
    );
  },
  routes: [
    GoRoute(
      path: '/dashboard/:dashboardId/overview',
      name: 'dashboard_overview',
      builder: (context, state) => const OverviewScreen(),
    ),
    GoRoute(
      path: '/dashboard/:dashboardId/analytics',
      name: 'dashboard_analytics',
      builder: (context, state) => const AnalyticsScreen(),
    ),
  ],
)

```

---

## 4. Technical Constraints & Edge Cases

| Scenario | Risk | Mitigation |
| --- | --- | --- |
| **Direct Web Link / Deep Linking** | Direct URL entry misses `extra` payload state. | Avoid relying strictly on `state.extra` for critical scoping; extract path parameters or query params via URL. |
| **Root Navigator Modal Pushes** | Pushing a full-screen route via `rootNavigatorKey` bypasses the `ShellRoute`. | If the modal requires scoped providers, wrap the modal destination in an `UncontrolledProviderScope` explicitly. |
| **Route Overrides Collisions** | Ambiguous path matching causes wrong route removal. | Prefer explicit `name` identifiers on all `GoRoute` instances across feature packages. |

---

## 5. Non-Functional Requirements

1. **Performance:** Route resolution must occur synchronously during app initialization (`< 5ms` total execution overhead).
2. **Maintainability:** Adding a new feature package must require editing only `main.dart` (or the core router initialization block).
3. **Testability:** Every `FeatureRouteModule` must be unit-testable in isolation using a mock `GoRouter` container without pumping the entire app widget tree.
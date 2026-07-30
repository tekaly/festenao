import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'route_location.dart';
import 'route_path.dart';

/// Type safe and relative navigation, on top of go_router.
///
/// Everything here is expressed in terms of the **active** location, so no
/// screen ever has to parse or rebuild its parent path by hand.
extension FestenaoNavigatorContextExt on BuildContext {
  /// The active location, path parameters included
  /// (`/school/124/student/456`).
  Uri get routeUri => GoRouterState.of(this).uri;

  /// The active location as a string.
  String get routeLocation => routeUri.toString();

  /// The path parameters of the active route.
  Map<String, String> get routePathParameters =>
      GoRouterState.of(this).pathParameters;

  /// Goes to [def], taking the path parameters of the active route and
  /// completing/overriding them with [parameters].
  ///
  /// This is the type safe jump: parameters shared with the current location
  /// (the school id when moving from a student to a class of that school) are
  /// inherited, and a missing one throws instead of navigating nowhere.
  void goPath(
    RoutePathDef def, {
    Map<String, String> parameters = const {},
    Object? extra,
  }) => GoRouter.of(this).go(
    def.locationFrom(GoRouterState.of(this), parameters: parameters),
    extra: extra,
  );

  /// Pushes [def] on top of the current route, inheriting path parameters the
  /// same way [goPath] does.
  Future<T?> pushPath<T extends Object?>(
    RoutePathDef def, {
    Map<String, String> parameters = const {},
    Object? extra,
  }) => GoRouter.of(this).push<T>(
    def.locationFrom(GoRouterState.of(this), parameters: parameters),
    extra: extra,
  );

  /// Replaces the current route by [def], inheriting path parameters the same
  /// way [goPath] does.
  void replacePath<T extends Object?>(
    RoutePathDef def, {
    Map<String, String> parameters = const {},
    Object? extra,
  }) => GoRouter.of(this).replace<T>(
    def.locationFrom(GoRouterState.of(this), parameters: parameters),
    extra: extra,
  );

  /// Goes deeper, appending [path] to the active location
  /// (`student/456` from `/school/124`).
  void goDeeper(String path, {Object? extra}) => GoRouter.of(
    this,
  ).go(routeLocationAppend(routeLocation, path), extra: extra);

  /// Pushes [path], appended to the active location.
  Future<T?> pushDeeper<T extends Object?>(String path, {Object? extra}) =>
      GoRouter.of(
        this,
      ).push<T>(routeLocationAppend(routeLocation, path), extra: extra);

  /// Jumps sideways: replaces the last [count] segments of the active
  /// location by [path].
  ///
  /// From `/school/124/student/456`, the classes of the same school are
  /// `goSibling('clas', count: 2)`.
  void goSibling(String path, {int count = 1, Object? extra}) => GoRouter.of(
    this,
  ).go(routeLocationSibling(routeLocation, path, count: count), extra: extra);

  /// Goes up [count] segments of the active location, without popping (this
  /// works on a deep link opened directly on a child location, where there is
  /// nothing to pop).
  void goUp([int count = 1]) =>
      GoRouter.of(this).go(routeLocationParent(routeLocation, count));

  /// Pops the current route, or goes to [def] when there is nothing to pop.
  ///
  /// This is what a screen reached by a deep link needs. Pushed from its
  /// parent, it has a stack to pop; opened directly — a fresh page load on the
  /// web, or a route mounted at the top level rather than under its parent —
  /// it has none, and popping would leave the user stuck. Path parameters
  /// missing from [parameters] are inherited from the active location, so
  /// going up from `/project/x/blog_demo` to [def] `/project/:project_id`
  /// needs no argument.
  void popOrGoPath(
    RoutePathDef def, {
    Map<String, String> parameters = const {},
  }) {
    var router = GoRouter.of(this);
    if (router.canPop()) {
      router.pop();
    } else {
      goPath(def, parameters: parameters);
    }
  }

  /// Pops the current route, or goes up [count] segments of the active
  /// location when there is nothing to pop.
  ///
  /// The untyped counterpart of [popOrGoPath], for the screens that have no
  /// [RoutePathDef] for their parent.
  void popOrGoUp([int count = 1]) {
    var router = GoRouter.of(this);
    if (router.canPop()) {
      router.pop();
    } else {
      goUp(count);
    }
  }
}

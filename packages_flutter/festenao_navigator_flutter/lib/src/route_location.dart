/// Pure (widget-free) location string helpers used by the relative navigation
/// extensions.
///
/// A location is the absolute path part of the current route
/// (`/school/124/student/456`), optionally followed by a query string. All
/// helpers here keep the query string of [location] untouched unless the
/// appended path carries its own.
library;

/// Splits a location in its path segments, ignoring any query/fragment.
List<String> routeLocationSegments(String location) {
  var uri = Uri.parse(location);
  return uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
}

String _joinSegments(List<String> segments, {String? query}) {
  var path = '/${segments.join('/')}';
  if (query?.isNotEmpty ?? false) {
    return '$path?$query';
  }
  return path;
}

/// Appends [path] (a relative path such as `student/456`) to [location].
///
/// ```dart
/// routeLocationAppend('/school/124', 'student/456'); // /school/124/student/456
/// ```
String routeLocationAppend(String location, String path) {
  var uri = Uri.parse(location);
  var appended = Uri.parse(path);
  var segments = [
    ...uri.pathSegments.where((segment) => segment.isNotEmpty),
    ...appended.pathSegments.where((segment) => segment.isNotEmpty),
  ];
  return _joinSegments(
    segments,
    query: appended.hasQuery ? appended.query : uri.query,
  );
}

/// Removes the last [count] segments of [location].
///
/// ```dart
/// routeLocationParent('/school/124/student/456');    // /school/124/student
/// routeLocationParent('/school/124/student/456', 2); // /school/124
/// ```
///
/// Never goes above the root (`/`). The query string is dropped since it
/// belongs to the popped location.
String routeLocationParent(String location, [int count = 1]) {
  var segments = routeLocationSegments(location);
  var keep = (segments.length - count).clamp(0, segments.length);
  return _joinSegments(segments.sublist(0, keep));
}

/// Replaces the last [count] segments of [location] by [path].
///
/// This is the "jump sideways" helper: from
/// `/school/124/student/456` you reach the classes of the same school with
/// `routeLocationSibling(location, 'clas', count: 2)`.
///
/// The query string is dropped, it belongs to the replaced location.
String routeLocationSibling(String location, String path, {int count = 1}) {
  return routeLocationAppend(routeLocationParent(location, count), path);
}

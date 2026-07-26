import 'package:go_router/go_router.dart';

/// A single part of a [RoutePathDef]: either a literal segment (`school`) or a
/// path parameter (`:school_id`).
class RoutePathPart {
  /// The part name, without the leading `:` for a parameter.
  final String name;

  /// True for a `:parameter` part.
  final bool isParameter;

  /// A literal segment.
  const RoutePathPart.literal(this.name) : isParameter = false;

  /// A `:name` path parameter.
  const RoutePathPart.parameter(this.name) : isParameter = true;

  /// Parses a single segment, `:name` becoming a parameter.
  factory RoutePathPart.parse(String segment) => segment.startsWith(':')
      ? RoutePathPart.parameter(segment.substring(1))
      : RoutePathPart.literal(segment);

  /// The go_router definition form (`school` or `:school_id`).
  String get definition => isParameter ? ':$name' : name;

  @override
  String toString() => definition;

  @override
  int get hashCode => Object.hash(name, isParameter);

  @override
  bool operator ==(Object other) =>
      other is RoutePathPart &&
      other.name == name &&
      other.isParameter == isParameter;
}

/// A route path definition, i.e. the declared (parameterized) location of a
/// screen, such as `/school/:school_id/student/:student_id`.
///
/// Definitions are built by chaining [child] so each definition knows its
/// [parent]. That is what makes [relativePath] (the string to pass to a nested
/// [GoRoute]) and parameter inheritance work without any manual string
/// concatenation:
///
/// ```dart
/// var schoolListPath = RoutePathDef.parse('/school', name: 'school_list');
/// var schoolPath = schoolListPath.child(':school_id', name: 'school');
/// var studentListPath = schoolPath.child('student', name: 'student_list');
/// var studentPath = studentListPath.child(':student_id', name: 'student');
///
/// studentPath.path;         // /school/:school_id/student/:student_id
/// studentPath.relativePath; // :student_id
/// studentPath.location({'school_id': '124', 'student_id': '456'});
/// ```
class RoutePathDef {
  /// The parent definition, null for a root definition.
  final RoutePathDef? parent;

  /// The parts of this definition, relative to [parent].
  final List<RoutePathPart> parts;

  /// The route name, used as [GoRoute.name] and as the identity used by
  /// route overrides. Strongly recommended on every definition.
  final String? name;

  RoutePathDef._({required this.parent, required this.parts, this.name});

  /// Parses `school/:school_id` (or `/school/:school_id`) into a definition.
  ///
  /// Leading and trailing separators are ignored; a root definition (no
  /// [parent]) is always absolute.
  factory RoutePathDef.parse(
    String path, {
    RoutePathDef? parent,
    String? name,
  }) {
    var parts = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(RoutePathPart.parse)
        .toList();
    return RoutePathDef._(parent: parent, parts: parts, name: name);
  }

  /// A child definition, [path] being relative to this definition.
  RoutePathDef child(String path, {String? name}) =>
      RoutePathDef.parse(path, parent: this, name: name);

  /// All the parts, this definition's ones prefixed by its ancestors'.
  late final List<RoutePathPart> allParts = [...?parent?.allParts, ...parts];

  /// The absolute definition path (`/school/:school_id/student/:student_id`).
  String get path => '/${allParts.map((part) => part.definition).join('/')}';

  /// The definition path relative to [parent], to use as the `path` of a
  /// [GoRoute] nested under the parent's [GoRoute].
  ///
  /// A root definition (no [parent]) returns its absolute [path].
  String get relativePath =>
      parent == null ? path : parts.map((part) => part.definition).join('/');

  /// The definition path relative to [ancestor], or the absolute [path] when
  /// [ancestor] is null.
  ///
  /// Throws an [ArgumentError] when [ancestor] is not an ancestor of this
  /// definition. Use this when the go_router tree skips a definition level.
  String relativeTo(RoutePathDef? ancestor) {
    if (ancestor == null) {
      return path;
    }
    var parts = <RoutePathPart>[];
    RoutePathDef? current = this;
    while (current != null && !identical(current, ancestor)) {
      parts.insertAll(0, current.parts);
      current = current.parent;
    }
    if (current == null) {
      throw ArgumentError.value(
        ancestor,
        'ancestor',
        '$ancestor is not an ancestor of $this',
      );
    }
    return parts.map((part) => part.definition).join('/');
  }

  /// The names of every path parameter, ancestors included, in path order.
  List<String> get parameterNames => allParts
      .where((part) => part.isParameter)
      .map((part) => part.name)
      .toList();

  /// The concrete location for [parameters], e.g. `/school/124/student/456`.
  ///
  /// Throws an [ArgumentError] naming the first missing parameter, so a typo
  /// fails loudly at the call site instead of silently navigating nowhere.
  String location([Map<String, String> parameters = const {}]) {
    var segments = allParts.map((part) {
      if (!part.isParameter) {
        return part.name;
      }
      var value = parameters[part.name];
      if (value == null || value.isEmpty) {
        throw ArgumentError.value(
          parameters,
          'parameters',
          'missing path parameter \'${part.name}\' for $path',
        );
      }
      return Uri.encodeComponent(value);
    });
    return '/${segments.join('/')}';
  }

  /// The concrete location for this definition, taking the path parameters of
  /// the current [state] and completing/overriding them with [parameters].
  ///
  /// This is the parameter inheritance helper: navigating from
  /// `/school/124/student/456` to the student's classes only needs
  /// `clasListPath.locationFrom(state)`, `school_id` and `student_id` being
  /// inherited from the active route.
  String locationFrom(
    GoRouterState state, {
    Map<String, String> parameters = const {},
  }) => location({...state.pathParameters, ...parameters});

  @override
  String toString() => name == null ? path : '$name($path)';
}

/// Path parameter access.
extension RoutePathGoRouterStateExt on GoRouterState {
  /// The value of the [name] path parameter, or null.
  String? pathParameterOrNull(String name) => pathParameters[name];

  /// The value of the [name] path parameter.
  ///
  /// Throws a [StateError] when missing, which means the route definition and
  /// the screen reading it disagree.
  String pathParameter(String name) {
    var value = pathParameterOrNull(name);
    if (value == null) {
      throw StateError('missing path parameter \'$name\' in $uri');
    }
    return value;
  }
}

/// [GoRoute] building helpers.
extension RoutePathDefGoRouteExt on RoutePathDef {
  /// A [GoRoute] for this definition, using [relativePath] (or the absolute
  /// [path] for a root definition) and [name] so overrides and
  /// `goNamed`/`pushNamed` keep working.
  ///
  /// Set [absolute] for a route that is not nested under a [GoRoute] for its
  /// [RoutePathDef.parent] — typically the direct children of a top level
  /// [ShellRoute], which go_router requires to be absolute since a shell adds
  /// nothing to the location.
  ///
  /// Pass [ancestor] when the go_router tree nests less deeply than the
  /// definition tree (a definition level with no route of its own).
  GoRoute goRoute({
    GoRouterWidgetBuilder? builder,
    GoRouterPageBuilder? pageBuilder,
    List<RouteBase> routes = const [],
    GoRouterRedirect? redirect,
    ExitCallback? onExit,
    RoutePathDef? ancestor,
    bool absolute = false,
  }) {
    return GoRoute(
      path: absolute
          ? path
          : (ancestor == null ? relativePath : relativeTo(ancestor)),
      name: name,
      builder: builder,
      pageBuilder: pageBuilder,
      routes: routes,
      redirect: redirect,
      onExit: onExit,
    );
  }
}

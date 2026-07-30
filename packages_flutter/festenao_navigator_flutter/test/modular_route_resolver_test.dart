import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _never(BuildContext context, GoRouterState state) =>
    throw StateError('never built');

GoRoute _route(
  String path, {
  String? name,
  List<RouteBase> routes = const [],
}) => GoRoute(path: path, name: name, builder: _never, routes: routes);

FeatureRouteModule _module(String moduleId, List<RouteBase> routes) =>
    FeatureRouteModuleBase(moduleId: moduleId, routes: routes);

extension on List<RouteBase> {
  List<String?> get names => map((route) => (route as GoRoute).name).toList();
  List<String> get paths => map((route) => (route as GoRoute).path).toList();
}

/// A module contributing [routes] under the route named [parentRouteName].
class _NestedModule implements NestedFeatureRouteModule {
  _NestedModule(this.moduleId, this.parentRouteName, this.routes);

  @override
  final String moduleId;

  @override
  final String parentRouteName;

  @override
  final List<RouteBase> routes;
}

/// The full paths of [routes], parent path included, in tree order.
List<String> _paths(List<RouteBase> routes, [String parent = '']) {
  var paths = <String>[];
  for (var route in routes) {
    if (route is! GoRoute) {
      paths.addAll(_paths(route.routes, parent));
      continue;
    }
    var path = route.path.startsWith('/')
        ? route.path
        : '${parent == '/' ? '' : parent}/${route.path}';
    paths.add(path);
    paths.addAll(_paths(route.routes, path));
  }
  return paths;
}

/// A tree a nested module can hang from.
List<RouteBase> _projectTree() => [
  _route(
    '/',
    name: 'home',
    routes: [
      _route(
        'project/:project_id',
        name: 'project',
        routes: [_route('data/:data_id', name: 'project_data')],
      ),
    ],
  ),
];

void main() {
  group('routeMatchesOverride', () {
    test('matches on the name when both are named', () {
      expect(
        routeMatchesOverride(
          _route('/school', name: 'school_list'),
          _route('/other', name: 'school_list'),
        ),
        isTrue,
      );
    });

    test('a name never matches a different name, same path or not', () {
      expect(
        routeMatchesOverride(
          _route('/school', name: 'school_list'),
          _route('/school', name: 'custom_school_list'),
        ),
        isFalse,
      );
    });

    test('matches on the path when a name is missing', () {
      expect(
        routeMatchesOverride(_route('/school'), _route('/school')),
        isTrue,
      );
      expect(
        routeMatchesOverride(
          _route('/school', name: 'school_list'),
          _route('/school'),
        ),
        isTrue,
      );
      expect(
        routeMatchesOverride(_route('/school'), _route('/students')),
        isFalse,
      );
    });

    test('a ShellRoute never matches', () {
      var shell = ShellRoute(
        builder: (context, state, child) => child,
        routes: [_route('/school')],
      );
      expect(routeMatchesOverride(shell, _route('/school')), isFalse);
      expect(routeMatchesOverride(_route('/school'), shell), isFalse);
    });
  });

  group('assembleRoutes', () {
    test('merges the modules in order', () {
      var routes = ModularRouteResolver.assembleRoutes(
        baseModules: [
          _module('school', [_route('/school'), _route('/student')]),
          _module('auth', [_route('/sign-in')]),
        ],
      );
      expect(routes.paths, ['/school', '/student', '/sign-in']);
    });

    test('replaces a named route in place', () {
      var routes = ModularRouteResolver.assembleRoutes(
        baseModules: [
          _module('school', [
            _route('/school', name: 'school_list'),
            _route('/student', name: 'student_list'),
          ]),
          _module('auth', [_route('/sign-in', name: 'sign_in')]),
        ],
        customOverrides: [_route('/my-schools', name: 'school_list')],
      );
      expect(routes.names, ['school_list', 'student_list', 'sign_in']);
      expect(routes.paths, ['/my-schools', '/student', '/sign-in']);
    });

    test('replaces an unnamed route in place, by path', () {
      var routes = ModularRouteResolver.assembleRoutes(
        baseModules: [
          _module('school', [_route('/school'), _route('/student')]),
        ],
        customOverrides: [_route('/school', name: 'custom_school_list')],
      );
      expect(routes.paths, ['/school', '/student']);
      expect(routes.names, ['custom_school_list', null]);
    });

    test('keeps the nested routes carried by the override', () {
      var routes = ModularRouteResolver.assembleRoutes(
        baseModules: [
          _module('school', [
            _route(
              '/school',
              name: 'school_list',
              routes: [_route(':school_id')],
            ),
          ]),
        ],
        customOverrides: [
          _route(
            '/school',
            name: 'school_list',
            routes: [_route(':school_id'), _route('new')],
          ),
        ],
      );
      expect(routes.length, 1);
      expect(routes.first.routes.paths, [':school_id', 'new']);
    });

    test('appends an override matching nothing', () {
      var routes = ModularRouteResolver.assembleRoutes(
        baseModules: [
          _module('school', [_route('/school', name: 'school_list')]),
        ],
        customOverrides: [_route('/about', name: 'about')],
      );
      expect(routes.names, ['school_list', 'about']);
    });

    test('no module, no override', () {
      expect(ModularRouteResolver.assembleRoutes(baseModules: []), isEmpty);
    });

    test('mounts a nested module under its parent route', () {
      var routes = ModularRouteResolver.assembleRoutes(
        baseModules: [
          _module('top', _projectTree()),
          _NestedModule('demo', 'project', [
            _route('blog_demo', name: 'blog_demo'),
          ]),
          _NestedModule('media', 'project_data', [
            _route('media/:media_id', name: 'media'),
          ]),
        ],
      );
      expect(_paths(routes), [
        '/',
        '/project/:project_id',
        '/project/:project_id/data/:data_id',
        '/project/:project_id/data/:data_id/media/:media_id',
        '/project/:project_id/blog_demo',
      ]);
    });

    test('mounts whatever the module order is', () {
      var routes = ModularRouteResolver.assembleRoutes(
        baseModules: [
          _NestedModule('demo', 'project', [
            _route('blog_demo', name: 'blog_demo'),
          ]),
          _module('top', _projectTree()),
        ],
      );
      expect(_paths(routes), contains('/project/:project_id/blog_demo'));
    });

    test('throws when a nested module names an unknown parent', () {
      expect(
        () => ModularRouteResolver.assembleRoutes(
          baseModules: [
            _module('top', _projectTree()),
            _NestedModule('orphan', 'nowhere', [_route('lost')]),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('replaces a route nested deep in the tree', () {
      var replacement = _route('blog_demo', name: 'blog_demo');
      var routes = ModularRouteResolver.assembleRoutes(
        baseModules: [
          _module('top', _projectTree()),
          _NestedModule('demo', 'project', [
            _route('blog_demo', name: 'blog_demo'),
          ]),
        ],
        customOverrides: [replacement],
      );
      // Same tree…
      expect(_paths(routes), [
        '/',
        '/project/:project_id',
        '/project/:project_id/data/:data_id',
        '/project/:project_id/blog_demo',
      ]);
      // …and the override is the route that ended up in it.
      var project = (routes.single as GoRoute).routes.single as GoRoute;
      expect(
        project.routes.firstWhere(
          (route) => (route as GoRoute).name == 'blog_demo',
        ),
        same(replacement),
      );
    });

    test('throws on a duplicated module id', () {
      expect(
        () => ModularRouteResolver.assembleRoutes(
          baseModules: [
            _module('school', [_route('/school')]),
            _module('school', [_route('/student')]),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}

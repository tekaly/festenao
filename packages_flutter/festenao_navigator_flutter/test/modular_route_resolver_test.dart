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

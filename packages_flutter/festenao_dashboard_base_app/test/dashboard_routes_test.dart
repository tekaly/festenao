import 'package:festenao_dashboard_base_app/router.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  group('dashboardBaseRouteModules', () {
    test('assembled tree', () {
      var paths = _paths(
        ModularRouteResolver.assembleRoutes(
          baseModules: dashboardBaseRouteModules(),
        ),
      );
      // The demo and media features are mounted inside the project branch, not
      // at the top level: a location opened directly builds its whole ancestor
      // stack, so there is always a parent to go back to.
      expect(paths, [
        '/',
        '/project/:project_id',
        '/project/:project_id/data/:data_id',
        '/project/:project_id/data/:data_id/images',
        '/project/:project_id/data/:data_id/medias',
        '/project/:project_id/data/:data_id/image_create',
        '/project/:project_id/data/:data_id/image/:image_id',
        '/project/:project_id/data/:data_id/image/:image_id/view',
        '/project/:project_id/data/:data_id/image/:image_id/edit',
        '/project/:project_id/data/:data_id/media/:media_id',
        '/project/:project_id/data/:data_id/media_edit/:media_id',
        '/project/:project_id/data/:data_id/media_create',
        '/project/:project_id/blog_demo',
        '/project/:project_id/legacy_blog_demo',
        '/project/:project_id/content_demo',
        '/projects_access',
        '/project_access/:project_id',
      ]);
    });

    test('the blog demo is a child of the project route', () {
      var routes = ModularRouteResolver.assembleRoutes(
        baseModules: dashboardBaseRouteModules(),
      );
      var home = routes.first as GoRoute;
      var project = home.routes.whereType<GoRoute>().firstWhere(
        (route) => route.name == dashboardProjectPath.name,
      );
      expect(
        project.routes.whereType<GoRoute>().map((route) => route.name),
        contains(blogDemoPath.name),
      );
    });
  });
}

import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('routeLocationAppend', () {
    test('append', () {
      expect(
        routeLocationAppend('/school/124', 'student'),
        '/school/124/student',
      );
      expect(
        routeLocationAppend('/school/124', 'student/456'),
        '/school/124/student/456',
      );
      expect(routeLocationAppend('/', 'school'), '/school');
      expect(
        routeLocationAppend('/school/124', '/student'),
        '/school/124/student',
      );
    });

    test('keeps the current query, unless the appended path has one', () {
      expect(
        routeLocationAppend('/school?tab=1', 'student'),
        '/school/student?tab=1',
      );
      expect(
        routeLocationAppend('/school?tab=1', 'student?tab=2'),
        '/school/student?tab=2',
      );
    });
  });

  group('routeLocationParent', () {
    test('up', () {
      expect(
        routeLocationParent('/school/124/student/456'),
        '/school/124/student',
      );
      expect(routeLocationParent('/school/124/student/456', 2), '/school/124');
      expect(routeLocationParent('/school'), '/');
    });

    test('never goes above the root', () {
      expect(routeLocationParent('/school', 5), '/');
      expect(routeLocationParent('/'), '/');
    });

    test('drops the query', () {
      expect(routeLocationParent('/school/124?tab=1'), '/school');
    });
  });

  group('routeLocationSibling', () {
    test('sideways', () {
      expect(
        routeLocationSibling('/school/124/student', 'clas'),
        '/school/124/clas',
      );
      expect(
        routeLocationSibling('/school/124/student/456', 'clas', count: 2),
        '/school/124/clas',
      );
      expect(
        routeLocationSibling('/school/124/student/456', 'clas/789', count: 2),
        '/school/124/clas/789',
      );
    });
  });

  group('encoded segments', () {
    // An id holding `/`, `#`, `?`, `%` or a space is percent encoded in the
    // location (RoutePathDef.location does it): the helpers must keep it so,
    // or the segment splits, turns into a query or a fragment.
    test('append keeps an encoded segment encoded', () {
      expect(
        routeLocationAppend('/project/a%2Fb', 'blog'),
        '/project/a%2Fb/blog',
      );
      expect(
        routeLocationAppend('/project/a%23b', 'blog'),
        '/project/a%23b/blog',
      );
      expect(
        routeLocationAppend('/project/a%3Fb?tab=1', 'blog'),
        '/project/a%3Fb/blog?tab=1',
      );
      expect(
        routeLocationAppend('/project/100%25', 'blog'),
        '/project/100%25/blog',
      );
      expect(
        routeLocationAppend('/project/a%20b', 'blog'),
        '/project/a%20b/blog',
      );
    });

    test('parent and sibling keep an encoded segment encoded', () {
      expect(routeLocationParent('/project/a%2Fb/blog'), '/project/a%2Fb');
      expect(
        routeLocationSibling('/project/a%23b/blog', 'data'),
        '/project/a%23b/data',
      );
    });

    test('a location built by RoutePathDef goes up to the same id', () {
      var projectPath = RoutePathDef.parse('/project/:project_id');
      var blogPath = projectPath.child('blog');
      for (var id in ['a/b', 'a#b', 'a?b', '100%', 'a b', 'é']) {
        var blog = blogPath.location({'project_id': id});
        expect(
          routeLocationParent(blog),
          projectPath.location({'project_id': id}),
        );
        expect(Uri.parse(routeLocationParent(blog)).pathSegments, [
          'project',
          id,
        ]);
      }
    });
  });
}

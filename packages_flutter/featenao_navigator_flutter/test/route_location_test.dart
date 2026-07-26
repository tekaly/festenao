import 'package:featenao_navigator_flutter/featenao_navigator_flutter.dart';
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
}

import 'package:featenao_navigator_flutter/featenao_navigator_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var schoolListPath = RoutePathDef.parse('/school', name: 'school_list');
  var schoolPath = schoolListPath.child(':school_id', name: 'school');
  var studentListPath = schoolPath.child('student', name: 'student_list');
  var studentPath = studentListPath.child(':student_id', name: 'student');
  var clasListPath = studentPath.child('clas', name: 'clas_list');
  var clasPath = clasListPath.child(':clas_id', name: 'clas');

  group('RoutePathPart', () {
    test('parse', () {
      expect(RoutePathPart.parse('school').isParameter, isFalse);
      expect(RoutePathPart.parse('school').definition, 'school');
      expect(RoutePathPart.parse(':school_id').isParameter, isTrue);
      expect(RoutePathPart.parse(':school_id').name, 'school_id');
      expect(RoutePathPart.parse(':school_id').definition, ':school_id');
    });
  });

  group('RoutePathDef', () {
    test('path', () {
      expect(schoolListPath.path, '/school');
      expect(schoolPath.path, '/school/:school_id');
      expect(studentListPath.path, '/school/:school_id/student');
      expect(studentPath.path, '/school/:school_id/student/:student_id');
      expect(
        clasPath.path,
        '/school/:school_id/student/:student_id/clas/:clas_id',
      );
    });

    test('relativePath', () {
      expect(schoolListPath.relativePath, '/school');
      expect(schoolPath.relativePath, ':school_id');
      expect(studentListPath.relativePath, 'student');
      expect(clasPath.relativePath, ':clas_id');
    });

    test('parse multiple parts at once', () {
      var def = schoolPath.child('student/:student_id');
      expect(def.relativePath, 'student/:student_id');
      expect(def.path, studentPath.path);
    });

    test('relativeTo', () {
      expect(
        clasPath.relativeTo(schoolPath),
        'student/:student_id/clas/:clas_id',
      );
      expect(clasPath.relativeTo(clasListPath), ':clas_id');
      expect(clasPath.relativeTo(null), clasPath.path);
      expect(() => schoolPath.relativeTo(clasPath), throwsArgumentError);
    });

    test('parameterNames', () {
      expect(schoolListPath.parameterNames, isEmpty);
      expect(clasPath.parameterNames, ['school_id', 'student_id', 'clas_id']);
    });

    test('location', () {
      expect(schoolListPath.location(), '/school');
      expect(schoolPath.location({'school_id': '124'}), '/school/124');
      expect(
        clasPath.location({
          'school_id': '124',
          'student_id': '456',
          'clas_id': '789',
        }),
        '/school/124/student/456/clas/789',
      );
    });

    test('location encodes values', () {
      expect(schoolPath.location({'school_id': 'a b'}), '/school/a%20b');
    });

    test('location throws on a missing parameter', () {
      expect(() => schoolPath.location(), throwsArgumentError);
      expect(
        () => clasPath.location({'school_id': '124'}),
        throwsArgumentError,
      );
      expect(() => schoolPath.location({'school_id': ''}), throwsArgumentError);
    });

    test('goRoute uses the relative path and the name', () {
      var route = studentPath.goRoute(
        builder: (context, state) => throw 'never',
      );
      expect(route.path, ':student_id');
      expect(route.name, 'student');
      var rootRoute = schoolListPath.goRoute(
        builder: (context, state) => throw 'never',
      );
      expect(rootRoute.path, '/school');
    });

    test('goRoute with an explicit ancestor', () {
      var route = clasPath.goRoute(
        ancestor: schoolPath,
        builder: (context, state) => throw 'never',
      );
      expect(route.path, 'student/:student_id/clas/:clas_id');
    });
  });
}

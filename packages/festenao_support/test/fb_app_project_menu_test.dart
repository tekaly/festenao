import 'dart:io';

import 'package:festenao_support/festenao_firebase_menu.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  group('FestenaoUserAccessGrant', () {
    test('read grants read only', () {
      var access = FestenaoUserAccessGrant.read.toUserAccess();
      expect(access.read.v, isTrue);
      expect(access.write.v, isFalse);
      expect(access.admin.v, isFalse);
      expect(access.role.v, isNull);
    });

    test('write grants read too', () {
      var access = FestenaoUserAccessGrant.write.toUserAccess();
      expect(access.read.v, isTrue);
      expect(access.write.v, isTrue);
      expect(access.admin.v, isFalse);
    });

    test('admin grants read and write too', () {
      var access = FestenaoUserAccessGrant.admin.toUserAccess();
      expect(access.read.v, isTrue);
      expect(access.write.v, isTrue);
      expect(access.admin.v, isTrue);
      expect(access.role.v, isNull);
    });

    test('superAdmin grants everything plus the role', () {
      var access = FestenaoUserAccessGrant.superAdmin.toUserAccess();
      expect(access.read.v, isTrue);
      expect(access.write.v, isTrue);
      expect(access.admin.v, isTrue);
      expect(access.role.v, 'super_admin');
    });
  });

  group('FestenaoFbAppProject', () {
    test('a service account map names the firebase project', () {
      var appProject = FestenaoFbAppProject.serviceAccountMap(
        appId: 'festenao_dev',
        serviceAccountMap: {'project_id': 'my-firebase-project'},
      );
      expect(appProject.appId, 'festenao_dev');
      expect(appProject.firebaseProjectId, 'my-firebase-project');
    });

    test('an explicit firebase project id wins over the map one', () {
      var appProject = FestenaoFbAppProject.serviceAccountMap(
        appId: 'festenao_dev',
        serviceAccountMap: {'project_id': 'from-the-map'},
        firebaseProjectId: 'explicit',
      );
      expect(appProject.firebaseProjectId, 'explicit');
    });

    test('the app is selected later, the global level needs none', () {
      var appProject = FestenaoFbAppProject.firebaseProjectId(
        firebaseProjectId: 'my-firebase-project',
      );
      expect(appProject.appId, isNull);
      expect(() => appProject.requireAppId, throwsStateError);
      appProject.appId = 'festenao_dev';
      expect(appProject.requireAppId, 'festenao_dev');
    });

    test('the context is built once, lazily', () async {
      var built = 0;
      var appProject = FestenaoFbAppProject(
        appId: 'festenao_dev',
        contextBuilder: () async {
          built++;
          throw UnimplementedError('no firebase in a unit test');
        },
      );
      // Declaring costs nothing.
      expect(built, 0);
      await expectLater(appProject.context, throwsUnimplementedError);
      expect(built, 1);
    });
  });

  group('firebaseFolderProjectId', () {
    test('a folder without firebase.json is refused', () {
      expect(
        () => firebaseFolderProjectId(path: Directory.systemTemp.path),
        throwsStateError,
      );
    });

    test('reads the default project of the .firebaserc', () {
      var dir = Directory.systemTemp.createTempSync('festenao_menu_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(join(dir.path, 'firebase.json')).writeAsStringSync('{}');
      File(
        join(dir.path, '.firebaserc'),
      ).writeAsStringSync('{"projects": {"default": "my-firebase-project"}}');
      expect(firebaseFolderProjectId(path: dir.path), 'my-firebase-project');
    });

    test('a .firebaserc without a default project is refused', () {
      var dir = Directory.systemTemp.createTempSync('festenao_menu_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(join(dir.path, 'firebase.json')).writeAsStringSync('{}');
      File(join(dir.path, '.firebaserc')).writeAsStringSync('{}');
      expect(() => firebaseFolderProjectId(path: dir.path), throwsStateError);
    });
  });
}

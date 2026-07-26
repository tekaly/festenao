// ignore_for_file: depend_on_referenced_packages

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:festenao_common/festenao_firebase_rest.dart';
import 'package:festenao_common/test/project_access_test_runner.dart';
import 'package:tekartik_firebase_emulator/firebase_emulator.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_server.dart';

var emulatorService = FirebaseEmulatorService(path: '.');

var firestoreEmulatorHost = 'localhost';
var firestoreEmulatorPort = 8080;

Future<void> expectPermissionError(Future<void> Function() action) async {
  try {
    await action();
    fail('should fail before');
  } catch (e) {
    expect(isExceptionPermissionError(e), isTrue, reason: '$e');
  }
}

Future<void> main() async {
  debugWebServices = true;
  debugFirestoreRest = true;
  var emulatorSupported = await emulatorService.isSupported();
  if (!emulatorSupported) {
    test('Firebase emulator not supported', () {
      stderr.writeln('Firebase emulator not supported');
    });
    return;
  }

  late FirebaseEmulator emulator;
  late String projectId;
  late FirebaseContext fbContext;
  late FirebaseAuth auth;
  late Firestore firestore;

  setUpAll(() async {
    initTkCmsFsBuilders();
    projectId = await emulatorService.getProjectId();
    emulator = await emulatorService.start(
      options: FirebaseEmulatorOptions(
        projectId: projectId,
        onlyFirestore: true,
        onlyAuth: true,
        debug: false,
      ),
    );

    fbContext = await (await initFirebaseServicesRest(
      appOptions: FirebaseAppOptions(projectId: projectId, apiKey: 'dummy'),
    )).init();
    await fbContext.useEmulator();
    auth = fbContext.auth;
    firestore = fbContext.firestore;
  });

  tearDownAll(() async {
    await fbContext.close();
    await emulator.stop();
  });

  group('project access', () {
    test('standalone project access', () async {
      var appId = 'test_app';
      var projectId2 = 'test_festenao_access_standalone';

      final projectCollectionInfo = fsProjectCollectionInfo;
      var entityAccess =
          TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsProject>(
            entityCollectionInfo: projectCollectionInfo,
            firestore: firestore,
            rootDocument: fsAppRoot(appId),
          );

      var userCredential = await auth.signInOrUpWithEmailAndPassword(
        email: 'admin@festenao-noff-test.local',
        password: 'test1234',
      );
      var userId = userCredential.user.uid;

      var accessRef = entityAccess.fsEntityUserAccessRef(projectId2, userId);

      // User cannot create the project without createUserId
      var entityRef = entityAccess.fsEntityRef(projectId2);

      // But cannot write it.
      await expectPermissionError(() async {
        await firestore.cvSet(entityRef.cv()..name.v = 'test');
      });

      print('$entityRef $userId');
      // It can create it with a userId
      await firestore.cvSet(
        entityRef.cv()
          ..name.v = 'test'
          ..creatorUserId.v = userId,
      );

      // But cannot write it yet.
      await expectPermissionError(() async {
        await firestore.cvSet(entityRef.cv()..name.v = 'test');
      });
      // Not read it
      await expectPermissionError(() async {
        await entityRef.get(firestore);
      });
      // User can write access.
      print('accessRef: $accessRef');
      await firestore.cvSet(accessRef.cv()..grantAdminAccess());

      // Remove admin access.
      await firestore.cvSet((accessRef.cv()..write.v = true)..fixAccess());
      // Can still write.
      await firestore.cvSet(
        entityRef.cv()
          ..name.v = 'test2'
          ..creatorUserId.v = userId,
      );
      await entityRef.get(firestore);

      // Remove write access.
      await firestore.cvSet((accessRef.cv()..read.v = true)..fixAccess());
      // Cannot write.
      await expectPermissionError(() async {
        await firestore.cvSet(entityRef.cv()..name.v = 'test3');
      });

      // Remove read access.
      await firestore.cvSet((accessRef.cv()..read.v = false)..fixAccess());
      // Cannot read.
      await expectPermissionError(() async {
        await entityRef.get(firestore);
      });

      await auth.signOut();

      // Cannot read.
      await expectPermissionError(() async {
        await entityRef.get(firestore);
      });
    });
  });

  group('creatorUserId sub entity access', () {
    test(
      'project creator can create sub entities without an access grant',
      () async {
        var appId = 'test_app';
        var projectId2 = 'test_creator_project';
        var itemId = 'test_item';

        var creatorCredential = await auth.signInOrUpWithEmailAndPassword(
          email: 'creator@festenao-noff-test.local',
          password: 'test1234',
        );
        var creatorUserId = creatorCredential.user.uid;
        await firestore
            .doc('app/$appId/project/$projectId2')
            .set({'name': 'test project', 'creatorUserId': creatorUserId});

        var itemRef = firestore.doc(
          'app/$appId/project/$projectId2/item/$itemId',
        );
        await itemRef.set({'name': 'test item'});

        await auth.signOut();

        await auth.signInOrUpWithEmailAndPassword(
          email: 'stranger@festenao-noff-test.local',
          password: 'test1234',
        );
        try {
          await firestore
              .doc('app/$appId/project/$projectId2/item/other_item')
              .set({'name': 'nope'});
          fail('should have failed');
        } catch (e) {
          expect(isExceptionPermissionError(e), isTrue, reason: '$e');
        }

        await auth.signOut();
      },
    );
  });
}

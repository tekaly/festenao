// ignore_for_file: depend_on_referenced_packages

@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_common/festenao_firebase_rest.dart';
import 'package:festenao_common/test/festenao_test_server_emulator_helper.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:festenao_common/test/project_access_test_runner.dart';
import 'package:festenao_common/test/project_api_access_test_runner.dart';
import 'package:festenao_common/test/user_prv_access_test_runner.dart';
import 'package:tekartik_firebase_emulator/firebase_emulator.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_server.dart';

var defaultRegion = regionBelgium;
var emulatorService = FirebaseEmulatorService(path: '.');

/// The "app" (top) entity id used by [FfApp] (its default `app` name).
var testAppId = 'festenao';
Future<void> main() async {
  debugWebServices = true;
  debugFirestoreRest = true;
  var emulatorSupported = await emulatorService.isSupported(
    options: emulatorTestRunnerOptions,
  );
  if (!emulatorSupported) {
    test('Firebase emulator not supported', () {
      stderr.writeln('Firebase emulator not supported');
    });
    return;
  }
  late FestenaoTestServerEmulatorContext testContext;
  late final firestore = testContext.clientContext.firestore!;

  group('api_festenao_access_test', () {
    setUpAll(() async {
      testContext = await initEmulatorServerContext(
        appId: testAppId,
        path: '.',
        region: defaultRegion,
      );
    });
    group('project api access', () {
      appProjectAccessApiTestRunner(() async => testContext.clientContext);
    });
    group('project access', () {
      appProjectAccessTestRunner(() async => testContext.clientContext);
    });
    group('project creator access', () {
      // These rules have no "Project Creator (standalone)" block, unlike
      // festenao_firebase_no_api_context: a client cannot create a project by
      // naming itself its creatorUserId, it has to go through the entity
      // create cloud function. Everything projectStandaloneAccessTestRunner
      // does is therefore refused here.
      appProjectCreatorUserIdApiTestRunner(
        () async => testContext.clientContext,
        creatorUserIdCreateSupported: false,
      );
    });
    group('user private data', () {
      appUserPrvAccessTestRunner(
        () => UserPrvAccessTestContext(
          auth: testContext.clientContext.firebaseAuth!,
          firestore: firestore,
        ),
      );
    });
    tearDownAll(() async {
      await testContext.close();
      await firestore.app.delete();
    });
  }, timeout: Timeout(Duration(minutes: 5)));
}

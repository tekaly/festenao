// ignore_for_file: depend_on_referenced_packages

@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_common/festenao_firebase_rest.dart';
import 'package:festenao_common/test/app_api_access_test_runner.dart';
import 'package:festenao_common/test/email_invite_rules_test_runner.dart';
import 'package:festenao_common/test/festenao_test_server_emulator_helper.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:festenao_common/test/project_access_test_runner.dart';
import 'package:festenao_common/test/user_prv_access_test_runner.dart';
import 'package:tekartik_firebase_emulator/firebase_emulator.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_server.dart';

var defaultRegion = regionBelgium;

/// Run from this folder whatever the current directory.
late FirebaseEmulatorService emulatorService;

/// The "app" (top) entity id used by [FfApp] (its default `app` name).
var testAppId = 'festenao';

/// The standalone context: the client reads and writes its entities
/// directly, invites by code and joins without the api, reads public
/// entities and its private data. The api only tests (email invites) run in
/// the full api context.
Future<void> main() async {
  emulatorService = FirebaseEmulatorService(
    path: await festenaoTestPackagePath(
      'tekaly_festenao_firebase_standalone_context',
    ),
  );
  debugWebServices = true;
  debugFirestoreRest = true;
  var emulatorSupported = await emulatorService.isSupported();
  if (!emulatorSupported) {
    test('Firebase emulator not supported', () {
      stderr.writeln('Firebase emulator not supported');
    });
    return;
  }
  late FestenaoTestServerEmulatorContext testContext;
  late final firestore = testContext.clientContext.firestore!;
  group('standalone_festenao_access_test', () {
    setUpAll(() async {
      testContext = await initEmulatorServerContext(
        appId: testAppId,
        path: emulatorService.path,
        region: defaultRegion,
      );
    });
    group('app admin access', () {
      appAccessApiTestRunner(() async => testContext.clientContext);
    });
    group('project access', () {
      appProjectStandaloneAccessTestRunner(
        () async => testContext.clientContext,
      );
      appProjectAccessTestRunner(() async => testContext.clientContext);
      appUserPrvAccessTestRunner(
        () => UserPrvAccessTestContext(
          auth: testContext.clientContext.firebaseAuth!,
          firestore: firestore,
        ),
      );

      appPublicAccessTestRunner(() async => testContext.clientContext);
      appProjectPublicAccessTestRunner(() async => testContext.clientContext);
    });
    // The addressed email invites are admin only data: the rules refuse
    // every client, the api is the only way in.
    group('email invite rules', () {
      appEmailInviteRulesTestRunner(() async => testContext);
    });
    tearDownAll(() async {
      await testContext.close();
      await firestore.app.delete();
    });
  }, timeout: Timeout(Duration(minutes: 5)));
}

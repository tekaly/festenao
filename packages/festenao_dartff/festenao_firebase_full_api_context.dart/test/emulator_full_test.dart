// ignore_for_file: depend_on_referenced_packages

@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_common/festenao_firebase_rest.dart';
import 'package:festenao_common/test/email_invite_rules_test_runner.dart';
import 'package:festenao_common/test/festenao_email_invite_test_runner.dart';
import 'package:festenao_common/test/festenao_invite_email_test_runner.dart';
import 'package:festenao_common/test/festenao_test_server_emulator_helper.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:festenao_common/test/full_api_client_refused_test_runner.dart';
import 'package:tekartik_firebase_emulator/firebase_emulator.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_server.dart';

var defaultRegion = regionBelgium;

/// Run from this folder whatever the current directory.
late FirebaseEmulatorService emulatorService;

/// The "app" (top) entity id used by [FfApp] (its default `app` name).
var testAppId = 'festenao';

/// The full api context: every read and write goes through the api, the
/// rules refuse the client everything.
///
/// Reserved for the time reads go through the api too: the tests reading
/// entity data through an access checked api come here when it exists.
Future<void> main() async {
  emulatorService = FirebaseEmulatorService(
    path: await festenaoTestPackagePath(
      'tekaly_festenao_firebase_full_api_context',
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
  group('full_api_festenao_test', () {
    setUpAll(() async {
      testContext = await initEmulatorServerContext(
        appId: testAppId,
        path: emulatorService.path,
        region: defaultRegion,
      );
    });
    group('client firestore refused', () {
      appFullApiClientRefusedTestRunner(() async => testContext);
    });
    group('email invite rules', () {
      appEmailInviteRulesTestRunner(() async => testContext);
    });
    // The addressed email invites; no verified email hook on the emulator
    // yet, the invitee tests are skipped.
    group('email invite (addressed)', () {
      testFestenaoEmailInviteGroup(
        () async => testContext,
        closeContext: false,
      );
    });
    // Last: the runner closes the context it is handed in its own tearDownAll,
    // which stops the emulator (closing again below is a no-op).
    group('invite by email', () {
      testFestenaoInviteEmailGroup(() async => testContext);
    });
    tearDownAll(() async {
      await testContext.close();
      await testContext.clientContext.firestore!.app.delete();
    });
  }, timeout: Timeout(Duration(minutes: 5)));
}

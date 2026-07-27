// ignore_for_file: depend_on_referenced_packages

@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_common/festenao_firebase_rest.dart';
import 'package:festenao_common/test/project_standalone_access_test_runner.dart';
import 'package:tekartik_firebase_emulator/firebase_emulator.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_server.dart';

var emulatorService = FirebaseEmulatorService(path: '.');

var firestoreEmulatorHost = 'localhost';
var firestoreEmulatorPort = 8080;

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

  projectStandaloneAccessTestRunner(
    () => ProjectStandaloneAccessTestContext(
      auth: auth,
      firestore: firestore,
    ),
    rulesSupported: true,
  );
}

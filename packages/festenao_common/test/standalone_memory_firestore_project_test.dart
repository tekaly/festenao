// ignore_for_file: depend_on_referenced_packages

@TestOn('vm')
library;

import 'package:festenao_common/test/project_standalone_access_test_runner.dart';
import 'package:tekartik_firebase_emulator/firebase_emulator.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

var emulatorService = FirebaseEmulatorService(path: '.');

var firestoreEmulatorHost = 'localhost';
var firestoreEmulatorPort = 8080;

Future<void> main() async {
  var fbContext = await initFirebaseServicesLocalMemory(
    projectId: 'standalone',
  ).init();
  final auth = fbContext.auth;
  final firestore = fbContext.firestore;

  tearDownAll(() async {
    await fbContext.close();
  });

  projectStandaloneAccessTestRunner(
    () => ProjectStandaloneAccessTestContext(auth: auth, firestore: firestore),
    rulesSupported: false,
  );
}

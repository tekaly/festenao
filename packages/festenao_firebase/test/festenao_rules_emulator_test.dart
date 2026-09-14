@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_firebase/firestore_rules_test_runner.dart';
import 'package:test/test.dart';

/// The festenao rules suite on the firebase emulator, the reference the
/// simulator suite is compared to.
Future<void> main() async {
  if (!await FirestoreRulesEmulator.isSupported()) {
    test('firebase emulator not supported', () {
      stderr.writeln('firebase emulator not supported');
    });
    return;
  }
  group('emulator', () {
    runFestenaoFirestoreRulesTests(
      () => FirestoreRulesEmulatorTestContext.create(
        rules: festenaoApiContextRules(),
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}

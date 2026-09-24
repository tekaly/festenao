@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_firebase/firestore_rules_test_runner.dart';
import 'package:test/test.dart';

import 'slug_rules_sim_test.dart';

/// The slug rules on the firebase emulator.
Future<void> main() async {
  if (!await FirestoreRulesEmulator.isSupported()) {
    test('firebase emulator not supported', () {
      stderr.writeln('firebase emulator not supported');
    });
    return;
  }
  group('emulator', () {
    runSlugRulesTests(
      (rules) => FirestoreRulesEmulatorTestContext.create(rules: rules),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

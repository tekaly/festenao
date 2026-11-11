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
    // In a group of its own: its context (and the emulator lock) is closed
    // before the next group starts another one.
    group('slug', () {
      runSlugRulesTests(
        (rules) => FirestoreRulesEmulatorTestContext.create(rules: rules),
      );
    });
    runSlugAppRightRulesTests(
      (rules) => FirestoreRulesEmulatorTestContext.create(rules: rules),
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}

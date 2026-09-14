@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_firebase/firestore_rules_test_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The festenao suite on the emulator running the hand written rules files
/// the presets replaced (kept in `test/data/legacy_rules`): the generated
/// rules must behave like the files they replace on every covered scenario.
Future<void> main() async {
  if (!await FirestoreRulesEmulator.isSupported()) {
    test('firebase emulator not supported', () {
      stderr.writeln('firebase emulator not supported');
    });
    return;
  }
  group('legacy rules on emulator', () {
    runFestenaoFirestoreRulesTests(
      () => FirestoreRulesEmulatorTestContext.create(
        rules: festenaoApiContextRules(),
      ),
      setRules: (ctx, preset) async {
        var file = File(
          p.join('test', 'data', 'legacy_rules', '$preset.rules'),
        );
        await ctx.setRulesText(await file.readAsString());
      },
    );
  }, timeout: const Timeout(Duration(minutes: 10)));
}

import 'dart:io';

import 'package:dev_build/shell.dart';
import 'package:festenao_firebase/festenao_firestore_rules.dart';
import 'package:festenao_firebase/firestore_rules_emulator.dart';

/// Starts the auth and firestore emulators with a preset
/// (`dart run tool/start_rules_emulator.dart [preset]`, `no_api_context` by
/// default), until enter is pressed. The emulator tests then reuse it (and
/// hot load their own rules).
Future<void> main(List<String> args) async {
  var name = args.isEmpty ? 'no_api_context' : args.first;
  var preset = festenaoRulesPresets[name];
  if (preset == null) {
    stderr.writeln('Unknown preset $name, one of ${festenaoRulesPresets.keys}');
    exit(1);
  }
  var emulator = await FirestoreRulesEmulator.start(rules: preset());
  stdout.writeln('Emulator started (${emulator.projectId}) with $name rules');
  await prompt('Press enter to stop the emulator');
  await emulator.stop();
  await promptTerminate();
}

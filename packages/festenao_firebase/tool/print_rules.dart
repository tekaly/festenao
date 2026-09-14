import 'dart:io';

import 'package:festenao_firebase/festenao_firestore_rules.dart';

/// Prints a preset: `dart run tool/print_rules.dart no_api_context`.
void main(List<String> args) {
  var name = args.isEmpty ? 'no_api_context' : args.first;
  var preset = festenaoRulesPresets[name];
  if (preset == null) {
    stderr.writeln('Unknown preset $name, one of ${festenaoRulesPresets.keys}');
    exit(1);
  }
  stdout.write(preset().toRulesText());
}

import 'dart:io';

import 'package:festenao_firebase/festenao_firestore_rules.dart';
import 'package:path/path.dart' as p;

/// The rules files generated from the presets, relative to the festenao
/// repository root.
final generatedRulesFiles = <String, FirestoreRules Function()>{
  'packages/festenao_dartff/firestore.rules': festenaoDartffRules,
  'packages/festenao_dartff/festenao_firebase_api_context.dart/firestore.rules':
      festenaoApiContextRules,
  'packages/festenao_dartff/festenao_firebase_no_api_context.dart/firestore.rules':
      festenaoNoApiContextRules,
  'packages/festenao_dartff/festenao_firebase_full_api_context.dart/firestore.rules':
      festenaoFullApiContextRules,
};

/// Regenerates the festenao rules files.
///
/// `dart run tool/generate_firestore_rules.dart [--check]`, `--check` only
/// reports the files that would change (exit code 1 if any).
Future<void> main(List<String> args) async {
  var check = args.contains('--check');
  var root = p.normalize(p.join(Directory.current.path, '..', '..'));
  var changed = 0;
  for (var entry in generatedRulesFiles.entries) {
    var file = File(p.join(root, entry.key));
    var text = entry.value().toRulesText();
    var existing = file.existsSync() ? await file.readAsString() : null;
    if (existing == text) {
      stdout.writeln('${entry.key}: up to date');
      continue;
    }
    changed++;
    if (check) {
      stdout.writeln('${entry.key}: would change');
    } else {
      await file.writeAsString(text);
      stdout.writeln('${entry.key}: written');
    }
  }
  if (check && changed > 0) {
    exit(1);
  }
}

/// Firestore security rules as code.
///
/// Build a rules file imperatively with [FirestoreRules] (functions, nested
/// match blocks, allow statements over a typed expression tree), then write it
/// with `toRulesText()` or evaluate it with the simulator
/// (`firestore_rules_sim.dart`).
library;

export 'src/rules/rules_builder.dart';
export 'src/rules/rules_expression.dart';
export 'src/rules/rules_writer.dart' show rulesToText;

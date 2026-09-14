/// In-memory simulation of the firestore security rules.
///
/// [FirestoreRulesSimulator] evaluates [FirestoreRules] the way the emulator
/// does and [RulesEnforcedFirestore] wraps any `Firestore` (typically the
/// in-memory one) so that every read and write is checked against them, the
/// wrapped instance keeping the admin (rules bypassing) access.
library;

export 'firestore_rules.dart';
export 'src/sim/rules_data_utils.dart' show computeRequestResourceData;
export 'src/sim/rules_enforced_firestore.dart';
export 'src/sim/rules_evaluator.dart';

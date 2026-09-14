/// Test support: the same rules test suite on the simulator and on the
/// emulator.
///
/// [FirestoreRulesTestContext] abstracts what a rules test needs (a rules
/// enforced firestore acting as the signed in user, an admin one to seed
/// data), implemented by [FirestoreRulesSimTestContext] (memory) and
/// [FirestoreRulesEmulatorTestContext] (emulator); [runFestenaoFirestoreRulesTests]
/// exercises the festenao presets on either.
library;

export 'festenao_firestore_rules.dart';
export 'firestore_rules_emulator.dart';
export 'firestore_rules_sim.dart';
export 'src/test/festenao_rules_test_suite.dart';
export 'src/test/firestore_rules_test_context.dart';

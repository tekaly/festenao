/// Firestore rules on the firebase emulator (io only).
///
/// [FirestoreRulesEmulator] starts the auth and firestore emulators on a
/// generated firebase folder carrying the rules under test, hot loads new
/// rules, and hands out rest clients: rules enforced ones (signed in through
/// the auth emulator) and an owner one that bypasses the rules to seed data.
library;

export 'firestore_rules.dart';
export 'src/emulator/firestore_rules_emulator.dart';

@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_firebase/firestore_rules_emulator.dart';
import 'package:tekartik_firebase_auth/auth.dart';
import 'package:test/test.dart';

/// Ports no other emulator test uses.
const _firestorePort = 18086;
const _authPort = 19096;

/// The emulator started on other ports than the default ones: the contexts
/// it hands out talk to those ports.
Future<void> main() async {
  if (!await FirestoreRulesEmulator.isSupported()) {
    test('firebase emulator not supported', () {
      stderr.writeln('firebase emulator not supported');
    });
    return;
  }
  test('user and owner contexts use the emulator ports', () async {
    var rules = FirestoreRules();
    rules.match('/t/{docId}', (m) {
      m.allow([RulesMethod.get], requestAuth.isNotNull);
    });
    var emulator = await FirestoreRulesEmulator.start(
      rules: rules,
      path: FirestoreRulesEmulator.defaultPath(
        '${firestoreRulesEmulatorDefaultProjectId}_ports',
      ),
      firestorePort: _firestorePort,
      authPort: _authPort,
    );
    try {
      var owner = await emulator.newOwnerContext();
      await owner.firestore.doc('t/1').set({'value': 1});
      var user = await emulator.newUserContext();
      await user.auth.signInOrUpWithEmailAndPassword(
        email: 'ports@rules.test',
        password: 'test1234',
      );
      expect((await user.firestore.doc('t/1').get()).data, {'value': 1});
      expect(await emulator.getUidByEmail('ports@rules.test'), isNotNull);
    } finally {
      await emulator.stop();
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

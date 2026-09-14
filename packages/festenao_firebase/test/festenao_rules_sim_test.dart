import 'package:festenao_firebase/firestore_rules_test_runner.dart';
import 'package:test/test.dart';

/// The festenao rules suite on the simulator (memory firestore and auth).
void main() {
  group('sim', () {
    runFestenaoFirestoreRulesTests(
      () =>
          FirestoreRulesSimTestContext.create(rules: festenaoApiContextRules()),
    );
  });
}

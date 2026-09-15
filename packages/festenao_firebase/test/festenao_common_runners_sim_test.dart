// ignore_for_file: depend_on_referenced_packages

import 'package:festenao_common/test/project_standalone_access_test_runner.dart';
import 'package:festenao_common/test/user_prv_access_test_runner.dart';
import 'package:festenao_firebase/firestore_rules_test_runner.dart';
import 'package:test/test.dart';

/// The existing festenao access runners (written for the emulator, with
/// `rulesSupported: true`) on the simulator running the no-api rules.
Future<void> main() async {
  var ctx = await FirestoreRulesSimTestContext.create(
    rules: festenaoNoApiContextRules(),
  );
  tearDownAll(() async {
    await ctx.close();
  });
  projectStandaloneAccessTestRunner(
    () => ProjectStandaloneAccessTestContext(
      auth: ctx.auth,
      firestore: ctx.firestore,
    ),
    rulesSupported: true,
  );
  appUserPrvAccessTestRunner(
    () => UserPrvAccessTestContext(auth: ctx.auth, firestore: ctx.firestore),
    rulesSupported: true,
  );
}

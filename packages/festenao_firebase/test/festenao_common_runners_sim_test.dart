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
  group(
    'standalone',
    () {
      projectStandaloneAccessTestRunner(
        () => ProjectStandaloneAccessTestContext(
          auth: ctx.auth,
          firestore: ctx.firestore,
        ),
        rulesSupported: true,
      );
    },
    // Fails on the emulator too (checked with the hand written rules as well
    // as the generated ones): `standaloneDeleteAndPurge` lists the `item`
    // sub collection of the project (its tree def) as the user, and no rule
    // allows a list under `{entity}/{entityId}` outside of `data`. The
    // simulator reproduces that denial; the runner or the tree def is to be
    // fixed upstream.
    skip:
        'standalone helpers/invited/public purge lists project/<id>/item, '
        'denied by the no-api rules on the emulator as well',
  );
  appUserPrvAccessTestRunner(
    () => UserPrvAccessTestContext(auth: ctx.auth, firestore: ctx.firestore),
    rulesSupported: true,
  );
}

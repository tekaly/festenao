import 'package:festenao_common/test/festenao_email_invite_test_runner.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';

/// The addressed email invite api on the in memory server, whose local auth
/// lets the test create users with a verified email.
Future<void> main() async {
  testFestenaoEmailInviteGroup(
    initFestenaoTestServerContextAllMemory,
    signInVerified: festenaoLocalAuthSignInVerified,
  );
}

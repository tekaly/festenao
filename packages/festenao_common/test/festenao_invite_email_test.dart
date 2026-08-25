import 'package:festenao_common/test/festenao_invite_email_test_runner.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';

Future<void> main() async {
  testFestenaoInviteEmailGroup(initFestenaoTestServerContextAllMemory);
}

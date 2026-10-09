import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:festenao_common/test/festenao_user_info_test_runner.dart';

/// The get user info command on the in memory server, whose local auth lets
/// the test create users with a name.
Future<void> main() async {
  testFestenaoUserInfoGroup(
    initFestenaoTestServerContextAllMemory,
    createUser: festenaoLocalAuthCreateUser,
  );
}

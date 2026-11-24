import 'package:festenao_common/test/festenao_set_user_access_test_runner.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:festenao_common/test/festenao_user_info_test_runner.dart';

/// The set user access command on the in memory server, whose local auth
/// lets the test create users with a name.
Future<void> main() async {
  testFestenaoSetUserAccessGroup(
    initFestenaoTestServerContextAllMemory,
    createUser: festenaoLocalAuthCreateUser,
  );
}

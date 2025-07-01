// ignore: unused_import
import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/test/festenao_test_server_test.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';

Future<void> main() async {
  // debugWebServices = devWarning(true);
  testFestenaoServerGroup(initFestenaoAllMemory);
}

import 'package:festenao_common/test/festenao_doc_test_server_test_runner.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';

Future<void> main() async {
  testFestenaoDocServerGroup(initFestenaoTestServerContextAllMemory);
}

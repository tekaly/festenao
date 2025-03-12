import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:tekartik_test_menu_browser/key_value_universal.dart';
import 'package:tekartik_test_menu_browser/test_menu_universal.dart';
import 'package:tkcms_common/tkcms_common.dart';

var serverUrl = 'FESTENAO_SERVER_URL'.kvFromVar(
  defaultValue: 'http://localhost:4999',
);
var vars = [serverUrl];
Future<void> main(List<String> args) async {
  await mainMenuUniversal(args, () {
    vars.dump();
    keyValuesMenu('Settings', vars);
    item('ampdev', () async {
      var commandUri = Uri.parse('${serverUrl.value}');
      write('${serverUrl.value}');
      // ignore: unused_local_variable
      var apiService = FestenaoApiService(
        httpsApiUri: commandUri,
        //app: tkCmsAppDev,
      );
      var ampUri = Uri.parse('${serverUrl.value}/ampdev/test');
      var ampService = FestenaoAmpService(httpsAmpUri: ampUri);
      var uri = ampService.pathUri('');
      write('uri: $uri');
      write(await read(uri));
    });
  });
}

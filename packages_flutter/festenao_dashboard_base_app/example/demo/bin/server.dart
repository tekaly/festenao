/// The cms site of the demo, served by the dart http function a deployment
/// runs (`cmsdemo`, `festenaoCmsSiteDartHandler` on the admin sdk http runner
/// of festenao_dartff), on a standalone local server.
///
/// ```sh
/// dart run bin/server.dart          # http://localhost:8040/cmsdemo/
/// dart run bin/server.dart 8080     # another port
/// ```
///
/// The pages are the demo ones, in memory: a restart brings them back.
library;

import 'package:festenao_dashboard_app_demo/src/demo_server.dart';
import 'package:festenao_dartff/functions.dart';

Future<void> main(List<String> args) async {
  var port =
      int.tryParse(args.firstOrNull ?? '') ?? festenaoFunctionsHttpServerPort;
  var server = await DemoServer.serveCms(port: port);
  // ignore: avoid_print
  print('cms site ${server.cmsSiteUrl}');
}

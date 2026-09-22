/// The festenao dart http functions of a dev `FfApp` (`commanddartv2dev`,
/// `callcommanddartv2dev`, `ampdev`) plus the cms site of the demo
/// (`cmsdev`), on a standalone local server: the admin sdk http runner of
/// festenao_dartff, the firebase services in memory.
///
/// ```sh
/// dart run bin/server_ff_app.dart          # http://localhost:8040/
/// dart run bin/server_ff_app.dart 8080     # another port
/// ```
///
/// Nothing is persisted: a restart brings the demo content back.
library;

import 'package:festenao_dashboard_app_demo/src/demo_server.dart';
import 'package:festenao_dartff/functions.dart';

Future<void> main(List<String> args) async {
  var port =
      int.tryParse(args.firstOrNull ?? '') ?? festenaoFunctionsHttpServerPort;
  var server = await DemoServer.serveFfApp(port: port);
  // ignore: avoid_print
  print('cms site ${server.cmsSiteUrl}');
}

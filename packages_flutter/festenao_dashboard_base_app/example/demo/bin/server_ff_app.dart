/// The festenao dart http functions of a dev `FfApp` (`commanddartv2dev`,
/// `callcommanddartv2dev`, `ampdev`, `cmsdev`) plus the demo cms site
/// (`cmsdemo`), on a standalone local server: the admin sdk http runner of
/// festenao_dartff, the firebase services in memory, a demo project seeded
/// whose site `cmsdev` serves.
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
  print('project cms site ${server.projectSiteUrl}');
  // ignore: avoid_print
  print('demo cms site ${server.cmsSiteUrl}');
}

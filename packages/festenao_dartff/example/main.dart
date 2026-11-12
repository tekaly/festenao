// ignore_for_file: avoid_print

import 'package:festenao_dartff/functions.dart';
import 'package:festenao_demo/festenao_demo_cms.dart';
import 'package:tekartik_http/http_memory.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// The festenao functions of a dev [FfApp], served as the deployed dart
/// functions run them (the admin sdk http runner), on in memory firebase
/// services and an in memory http server: no emulator, no network.
///
/// Remove `httpServerFactory:` to listen on http://localhost:8040 instead
/// (then `/cmsdev/<projectId>/<dataId>/` in a browser).
Future<void> main() async {
  var firebaseContext = initFirebaseServicesLocalMemory(
    projectId: 'festenao-example',
  ).initContext();
  // Some festenao_common server handlers read the global context.
  firebaseContextOrNull = firebaseContext;
  var ffApp = FfApp(
    context: TkCmsServerAppContext(
      firebaseContext: firebaseContext,
      flavorContext: FlavorContext.dev,
    ),
  );
  // A project whose synced content holds the demo pages.
  var project = await fillDemoCmsProject(
    firestore: firebaseContext.firestore,
    app: ffApp.app,
  );

  var functions = await serveFestenaoFunctionsHttp(
    httpServerFactory: httpFactoryMemory.server,
    firebaseApp: firebaseContext.firebaseApp,
    declare: (functions) {
      // commanddartv2dev, callcommanddartv2dev, ampdev, cmsdev
      declareRunner(ffApp, functions);
      // cmsdemo
      declareCmsDemoRunner(functions);
    },
  );
  var server = functions.httpServer;
  var client = httpFactoryMemory.client.newClient();
  try {
    var siteUri = httpServerGetUri(server).resolve(
      '/$festenaoCmsFunctionDev/${project.projectId}/${project.dataId}/',
    );
    var response = await client.get(siteUri);
    print('GET $siteUri: ${response.statusCode}');
    print(
      'the site name is in the page: '
      '${response.body.contains(demoCmsSiteName)}',
    );
  } finally {
    client.close();
    await server.close(force: true);
    await ffApp.cmsContentCache.close();
  }
}

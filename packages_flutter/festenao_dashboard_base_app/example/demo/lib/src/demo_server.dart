/// The standalone servers of the demo, free of Flutter: `bin/server.dart`
/// (the cms site) and `bin/server_ff_app.dart` (the festenao functions plus
/// the cms site), on the admin sdk http runner of festenao_dartff.
library;

import 'dart:async';

import 'package:festenao_common/festenao_cms.dart';
import 'package:festenao_dartff/functions.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_common/tkcms_server.dart';

import 'demo_cms_data.dart';

/// The name of the cms function of `bin/server.dart`.
const demoCmsFunctionName = 'cms';

/// A standalone server of the demo.
class DemoServer {
  /// The functions served.
  final FirebaseFunctionsAdminSdkHttp functions;

  /// The cms, whose site is served at [cmsSiteUrl].
  final DemoCms cms;

  /// The url of the cms site: the url of its function.
  final Uri cmsSiteUrl;

  /// The festenao app, in `bin/server_ff_app.dart`.
  final FfApp? ffApp;

  DemoServer._({
    required this.functions,
    required this.cms,
    required this.cmsSiteUrl,
    this.ffApp,
  });

  /// The http server.
  HttpServer get httpServer => functions.httpServer;

  /// The server url (`http://localhost:8040/`).
  Uri get uri => httpServerGetUri(httpServer);

  /// Stops serving.
  Future<void> close() async {
    await httpServer.close(force: true);
    await cms.database.close();
  }

  /// Serves the cms site of the demo as the function [cmsFunctionName], and
  /// [declare]s what else is served.
  static Future<DemoServer> _serve({
    required String cmsFunctionName,
    required int port,
    HttpServerFactory? httpServerFactory,
    FirebaseApp? firebaseApp,
    FfApp? ffApp,
  }) async {
    // The page links point to the function url, known once bound: a request
    // arriving before waits for the site.
    var cmsReady = Completer<DemoCms>();
    var functions = await serveFestenaoFunctionsHttp(
      port: port,
      httpServerFactory: httpServerFactory,
      firebaseApp: firebaseApp,
      declare: (functions) {
        if (ffApp != null) {
          declareRunner(ffApp, functions);
        }
        declareCmsSiteRunner(
          functions,
          name: cmsFunctionName,
          siteHandler: () async {
            var cms = await cmsReady.future;
            return CmsSiteHandler(
              pages: cms.pages,
              renderer: cms.renderer,
              pageOptions: cms.pageOptions,
            );
          },
        );
      },
    );
    var cmsSiteUrl = httpServerGetUri(
      functions.httpServer,
    ).replace(path: '/$cmsFunctionName/');
    var cms = await DemoCms.create(baseUrl: cmsSiteUrl);
    cmsReady.complete(cms);
    return DemoServer._(
      functions: functions,
      cms: cms,
      cmsSiteUrl: cmsSiteUrl,
      ffApp: ffApp,
    );
  }

  /// The cms site alone, as the function `cms`.
  static Future<DemoServer> serveCms({
    int port = festenaoFunctionsHttpServerPort,
    HttpServerFactory? httpServerFactory,
  }) => _serve(
    cmsFunctionName: demoCmsFunctionName,
    port: port,
    httpServerFactory: httpServerFactory,
  );

  /// The festenao functions of a dev [FfApp] (`commanddartv2dev`,
  /// `callcommanddartv2dev`, `ampdev`) on in memory firebase services, plus
  /// the cms site as `cmsdev`.
  static Future<DemoServer> serveFfApp({
    int port = festenaoFunctionsHttpServerPort,
    HttpServerFactory? httpServerFactory,
  }) async {
    var firebaseContext = initFirebaseServicesLocalMemory(
      projectId: 'festenao-demo',
    ).initContext();
    // Some festenao_common server handlers use the global context.
    firebaseContextOrNull = firebaseContext;
    var ffApp = FfApp(
      context: TkCmsServerAppContext(
        firebaseContext: firebaseContext,
        flavorContext: FlavorContext.dev,
      ),
    );
    return _serve(
      cmsFunctionName: festenaoCmsCommand(ffApp),
      port: port,
      httpServerFactory: httpServerFactory,
      firebaseApp: firebaseContext.firebaseApp,
      ffApp: ffApp,
    );
  }
}

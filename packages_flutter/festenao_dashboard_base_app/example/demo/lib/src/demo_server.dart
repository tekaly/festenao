/// The standalone servers of the demo, free of Flutter: `bin/server.dart`
/// (the demo cms site) and `bin/server_ff_app.dart` (the festenao functions,
/// the cms site of a seeded project, and the demo cms site), on the admin sdk
/// http runner of festenao_dartff.
library;

import 'dart:async';

import 'package:festenao_dartff/functions.dart';
import 'package:festenao_demo/festenao_demo_cms.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// A standalone server of the demo.
class DemoServer {
  /// The functions served.
  final FirebaseFunctionsAdminSdkHttp functions;

  /// The demo cms, whose site is served at [cmsSiteUrl].
  final DemoCms cms;

  /// The festenao app, in `bin/server_ff_app.dart`.
  final FfApp? ffApp;

  /// The demo project of [ffApp], whose site is served at [projectSiteUrl].
  final FestenaoCmsSiteRef? project;

  DemoServer._({
    required this.functions,
    required this.cms,
    this.ffApp,
    this.project,
  });

  /// The http server.
  HttpServer get httpServer => functions.httpServer;

  /// The server url (`http://localhost:8040/`).
  Uri get uri => httpServerGetUri(httpServer);

  /// The url of the demo cms site: the url of the [festenaoCmsDemoFunction]
  /// function.
  Uri get cmsSiteUrl => uri.replace(path: '/$festenaoCmsDemoFunction/');

  /// The url of the cms site of the demo [project] of [ffApp]:
  /// `<cmsdev>/<projectId>/<dataId>/`, null without an app.
  Uri? get projectSiteUrl {
    var project = this.project;
    if (project == null) {
      return null;
    }
    return uri.replace(
      path: '/${ffApp!.cmsCommand}/${project.projectId}/${project.dataId}/',
    );
  }

  /// Stops serving.
  Future<void> close() async {
    await httpServer.close(force: true);
    await ffApp?.cmsContentCache.close();
    await cms.database.close();
  }

  /// Serves the demo cms site as [festenaoCmsDemoFunction], and the
  /// functions of [ffApp].
  static Future<DemoServer> _serve({
    required int port,
    HttpServerFactory? httpServerFactory,
    FirebaseApp? firebaseApp,
    FfApp? ffApp,
    FestenaoCmsSiteRef? project,
  }) async {
    var cms = await DemoCms.create();
    // The links of the site follow the url of each request.
    var cmsServer = DemoCmsServer(cms: cms);
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
          name: festenaoCmsDemoFunction,
          handler: cmsServer.handle,
        );
      },
    );
    return DemoServer._(
      functions: functions,
      cms: cms,
      ffApp: ffApp,
      project: project,
    );
  }

  /// The demo cms site alone, as the function `cmsdemo`.
  static Future<DemoServer> serveCms({
    int port = festenaoFunctionsHttpServerPort,
    HttpServerFactory? httpServerFactory,
  }) => _serve(port: port, httpServerFactory: httpServerFactory);

  /// The festenao functions of a dev [FfApp] (`commanddartv2dev`,
  /// `callcommanddartv2dev`, `ampdev`, `cmsdev`) on in memory firebase
  /// services, the demo project seeded (its site served by `cmsdev`), plus
  /// the demo cms site as `cmsdemo`.
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
    var project = await fillDemoCmsProject(
      firestore: firebaseContext.firestore,
      app: ffApp.app,
    );
    return _serve(
      port: port,
      httpServerFactory: httpServerFactory,
      firebaseApp: firebaseContext.firebaseApp,
      ffApp: ffApp,
      project: project,
    );
  }
}

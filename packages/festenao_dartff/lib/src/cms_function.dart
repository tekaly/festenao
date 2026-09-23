import 'package:festenao_common/server/festenao_server_admin_sdk.dart';
import 'package:festenao_common/server/festenao_server_cms.dart';
import 'package:festenao_demo/festenao_demo_cms.dart';
import 'package:tekartik_firebase_functions_admin_sdk/functions_admin_sdk.dart';
import 'package:tekartik_firebase_functions_admin_sdk_http/functions_admin_sdk_http.dart';

export 'package:festenao_common/server/festenao_server_admin_sdk.dart';
export 'package:festenao_common/server/festenao_server_cms.dart'
    show
        festenaoCmsHostingPath,
        festenaoCmsFunctionProd,
        festenaoCmsFunctionDev,
        festenaoCmsDemoFunction;

/// The handler of the demo cms function ([festenaoCmsDemoFunction]): the
/// hard coded site of `festenao_demo` ([demoCmsServer]), at the url it is
/// reached at (`https://<hosting>/cmsdemo/`, the function url, a local
/// runner).
FirebaseFunctionsAdminSdkRequestHandler get festenaoCmsDemoDartHandler =>
    festenaoCmsSiteDartHandler(
      mountNames: [festenaoCmsDemoFunction],
      handler: demoCmsServer.handle,
    );

/// Registers the cms site function [name] on the admin sdk http runner, next
/// to the other functions a server declares (see `declareRunner`,
/// `serveFestenaoFunctionsHttp`): [handler] gets the requests, the leading
/// [name] (or one of [mountNames]) stripped.
void declareCmsSiteRunner(
  FirebaseFunctionsAdminSdkHttp functions, {
  required String name,
  Iterable<String>? mountNames,
  required FestenaoCmsRequestHandler handler,
}) {
  functions.https.onAdminSdkRequest(
    name,
    festenaoCmsSiteDartHandler(
      mountNames: mountNames ?? [name],
      handler: handler,
    ),
  );
}

/// Registers the demo cms function ([festenaoCmsDemoFunction]) on the admin
/// sdk http runner.
void declareCmsDemoRunner(FirebaseFunctionsAdminSdkHttp functions) {
  functions.https.onAdminSdkRequest(
    festenaoCmsDemoFunction,
    festenaoCmsDemoDartHandler,
  );
}

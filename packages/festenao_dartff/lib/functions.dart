import 'package:festenao_common/amp/amp_page.dart';
import 'package:festenao_common/server/festeano_server_app.dart';
import 'package:tekartik_firebase_functions_admin_sdk/functions_admin_sdk.dart';
import 'package:tekartik_firebase_functions_admin_sdk_http/functions_admin_sdk_http.dart';
import 'package:tkcms_common/server/server_admin_sdk.dart';
import 'package:tkcms_common/server/server_common.dart';

export 'package:festenao_common/server/festeano_server_app.dart';

export 'src/ff_app.dart';

/// The AMP command name for the given [app] flavor (amp vs ampdev).
String festenaoAmpCommand(FestenaoServerApp app) =>
    'amp${app.flavorContext.ifNotProdFlavor}';

/// Handler for the AMP HTTP function (served as plain HTTP since the admin SDK
/// does not support the express request flavor).
Future<Response> festenaoAmpDartV2Handler(
  FirebaseFunctions firebaseFunctions,
  Request request,
) async {
  var page = FestenaoAmpPage();
  return Response.ok(
    await page.build(),
    headers: {'content-type': 'text/html; charset=utf-8'},
  );
}

/// Declares the HTTP runner for admin SDK functions.
void declareRunner(
  FestenaoServerApp app,
  FirebaseFunctionsAdminSdkHttp functions,
) {
  if (app.flavorContext.isDev) {
    functions.https.onAdminSdkRequest(
      functionCommandDartV2Dev,
      app.functionsHttpDartV2Handler,
    );
    functions.https.onAdminSdkCall(
      callableFunctionCommandDartV2Dev,
      app.functionsCallDartV2Handler,
    );
  } else {
    functions.https.onAdminSdkRequest(
      functionCommandDartV2Prod,
      app.functionsHttpDartV2Handler,
    );
    functions.https.onAdminSdkCall(
      callableFunctionCommandDartV2Prod,
      app.functionsCallDartV2Handler,
    );
  }
  functions.https.onAdminSdkRequest(
    festenaoAmpCommand(app),
    festenaoAmpDartV2Handler,
  );
}

/// The dart (admin sdk) cloud functions handlers of a [FestenaoServerApp],
/// next to `package:tkcms_common/server/server_admin_sdk.dart` (the api
/// commands).
library;

import 'package:festenao_common/festenao_cms.dart';
import 'package:tekartik_firebase_functions_admin_sdk/functions_admin_sdk.dart';

import 'festeano_server_app.dart';

/// Serves a cms request, below the mount.
typedef FestenaoCmsRequestHandler =
    Future<CmsResponse> Function(CmsSiteRequest request);

/// An http function serving cms sites with [handler]: the request url, its
/// first segment stripped when one of [mountNames] (the hosting path, the
/// function name kept by the local runners), the base url of the site
/// derived from the forwarded headers of firebase hosting.
///
/// ```dart
/// firebase.https.onRequest(
///   name: festenaoCmsDemoFunction,
///   options: _httpsOptions,
///   firebase.httpsHandler(
///     festenaoCmsSiteDartHandler(
///       mountNames: [festenaoCmsDemoFunction],
///       handler: myCmsHandler,
///     ),
///   ),
/// );
/// ```
FirebaseFunctionsAdminSdkRequestHandler festenaoCmsSiteDartHandler({
  Iterable<String> mountNames = const [],
  required FestenaoCmsRequestHandler handler,
}) => (firebaseFunctions, request) async {
  CmsResponse response;
  try {
    response = await handler(
      CmsSiteRequest.fromUrl(
        request.requestedUri,
        mountNames: mountNames,
        forwardedHost: request.headers[httpHeaderXForwardedHost],
        forwardedProto: request.headers[httpHeaderXForwardedProto],
      ),
    );
  } catch (e) {
    response = CmsResponse.text('Error: $e', statusCode: 500);
  }
  return Response(
    response.statusCode,
    body: response.body,
    headers: festenaoCmsResponseHeaders(response),
  );
};

/// Admin sdk handlers of a [FestenaoServerApp].
extension FestenaoServerAppAdminSdkExt on FestenaoServerApp {
  /// The handler of the cms function ([FestenaoServerApp.cmsCommand]).
  FirebaseFunctionsAdminSdkRequestHandler get functionsCmsDartHandler =>
      festenaoCmsSiteDartHandler(
        mountNames: cmsMountNames,
        handler: handleCmsRequest,
      );
}

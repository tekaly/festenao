/// The dart (admin sdk) cloud functions handlers of a [FestenaoServerApp],
/// next to `package:tkcms_common/server/server_admin_sdk.dart` (the api
/// commands).
library;

import 'package:festenao_common/festenao_cms.dart';
import 'package:tekartik_firebase_functions_admin_sdk/functions_admin_sdk.dart';

import 'festeano_server_app.dart';
import 'festenao_object_storage_download_stream.dart';

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
    response = const CmsResponse.text('Internal error', statusCode: 500);
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

/// The https function of an api server whose files are streamed by the api
/// itself (`gdrive/getDownloadUrl` gives `<command>/gdrive/stream?token=`):
/// the stream endpoint when the request is one ([downloadStream], a 501
/// when the server has no storage), [onCommand] otherwise (the json
/// commands, `app.functionsHttpDartV2Handler`).
///
/// Without it, the command handler answers a stream request with a json
/// error (an empty body to parse), which a player then tries to play.
///
/// ```dart
/// firebase.https.onRequest(
///   name: functionCommandDartV2Dev,
///   options: _httpsOptions,
///   firebase.httpsHandler(
///     festenaoDownloadStreamHttpsHandler(
///       downloadStream: appDev.downloadStream,
///       onCommand: appDev.functionsHttpDartV2Handler,
///     ),
///   ),
/// );
/// ```
FirebaseFunctionsAdminSdkRequestHandler festenaoDownloadStreamHttpsHandler({
  required FestenaoObjectStorageDownloadStream? downloadStream,
  required FirebaseFunctionsAdminSdkRequestHandler onCommand,
}) => (firebaseFunctions, request) async {
  DownloadStreamResponse? stream;
  if (downloadStream != null) {
    stream = await downloadStream.onDownloadStreamOrNull(
      method: request.method,
      uri: request.url,
      range: request.headers['range'],
    );
  } else if (isObjectStorageDownloadStreamUri(request.url)) {
    stream = DownloadStreamResponse.error(501, 'No storage');
  }
  if (stream != null) {
    return Response(
      stream.statusCode,
      body: stream.body ?? stream.message,
      headers: stream.headers,
    );
  }
  return await onCommand(firebaseFunctions, request);
};

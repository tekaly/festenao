import 'dart:async';

import 'package:festenao_common/festenao_cms.dart';
import 'package:festenao_common/server/festeano_server_app.dart';
import 'package:tekartik_firebase_functions_admin_sdk/functions_admin_sdk.dart';
import 'package:tekartik_firebase_functions_admin_sdk_http/functions_admin_sdk_http.dart';

/// The site a cms function serves, resolved on each request (the pages
/// change, and the database can be opened lazily).
typedef FestenaoCmsSiteHandlerProvider = FutureOr<CmsSiteHandler> Function();

/// An http function serving the static site of a [CmsSiteHandler]: the
/// index, the pages, `sitemap.xml` and `robots.txt`, a 404 for anything else.
///
/// The site base url is the function url
/// (`https://<region>-<project>.cloudfunctions.net/<functionName>/`):
/// deployed, the request path is the one below the function; the local
/// runners keep [functionName] in front of it, and it is dropped.
///
/// ```dart
/// firebase.https.onRequest(
///   name: 'cmsdev',
///   options: _httpsOptions,
///   firebase.httpsHandler(
///     festenaoCmsSiteDartHandler(
///       functionName: 'cmsdev',
///       siteHandler: () => CmsSiteHandler(
///         pages: CmsPageSdb(db: contentDb),
///         renderer: CmsRenderer(
///           site: CmsSite(
///             name: 'My festival',
///             baseUrl: Uri.parse(
///               'https://europe-west1-my-project.cloudfunctions.net/cmsdev/',
///             ),
///           ),
///         ),
///       ),
///     ),
///   ),
/// );
/// ```
FirebaseFunctionsAdminSdkRequestHandler festenaoCmsSiteDartHandler({
  required String functionName,
  required FestenaoCmsSiteHandlerProvider siteHandler,
}) => (firebaseFunctions, request) async {
  var segments = request.requestedUri.path
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.firstOrNull == functionName) {
    segments = segments.sublist(1);
  }
  CmsResponse response;
  try {
    response = await (await siteHandler()).handlePath(segments.join('/'));
  } catch (e) {
    response = CmsResponse.text('Error: $e', statusCode: 500);
  }
  return Response(
    response.statusCode,
    body: response.body,
    headers: {
      'content-type': response.contentType,
      // Static pages, cached by the CDN a few minutes.
      if (response.isOk) 'cache-control': 'public, s-maxage=300, max-age=60',
    },
  );
};

/// The cms site function name for the given [app] flavor (`cms` vs `cmsdev`).
String festenaoCmsCommand(FestenaoServerApp app) =>
    'cms${app.flavorContext.ifNotProdFlavor}';

/// Registers the cms site function [name] on the admin sdk http runner
/// ([festenaoCmsSiteDartHandler] on [siteHandler]), next to the other
/// functions a server declares (see `declareRunner`,
/// `serveFestenaoFunctionsHttp`).
///
/// Give the site the function url as base url: `<server>/<name>/`.
void declareCmsSiteRunner(
  FirebaseFunctionsAdminSdkHttp functions, {
  required String name,
  required FestenaoCmsSiteHandlerProvider siteHandler,
}) {
  functions.https.onAdminSdkRequest(
    name,
    festenaoCmsSiteDartHandler(functionName: name, siteHandler: siteHandler),
  );
}

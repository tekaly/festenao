import 'package:festenao_common/amp/amp_page.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/festenao_cms.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tkcms_common/tkcms_server.dart';

import 'festeano_server_entity_handler.dart';
import 'festenao_server_cms.dart';

export 'festenao_server_cms.dart';

/// Server app for Festenao CMS.
///
/// Besides the api commands, it serves the cms sites of the projects: the
/// [cmsCommand] function (`cms`, `cmsdev`) renders the published pages of the
/// synced content database `app/<app>/project/<projectId>/data/<dataId>` at
///
/// ```
/// https://<hosting>/cms/<projectId>/<dataId>/             (hosting rewrite)
/// https://<hosting>/cms/<projectId>/<dataId>/page/<slug>
/// ```
///
/// see [handleCmsRequest] and the hooks it calls to customize a site.
class FestenaoServerApp extends TkAppCmsServerAppBase {
  /// AMP command name.
  late String ampCommand;

  /// Cms site function name ([festenaoCmsFunctionProd] in prod,
  /// [festenaoCmsFunctionDev] in dev).
  late final String cmsCommand =
      '$festenaoCmsFunctionProd${flavorContext.ifNotProdFlavor}';

  /// Creates a new [FestenaoServerApp] with the given [app], [context], and optional [version].
  FestenaoServerApp({
    String app = 'festenao',
    required super.context,
    super.version,
  }) : super(app, apiVersion: apiVersion2);

  /// True when this server may handle [app], whether named by an api
  /// command (`ApiRequest.app`) or a cms site url: a dev server handles no
  /// prod app, a prod server no dev app (see [festenaoIsDevApp]).
  ///
  /// Not checked yet, neither by [onCommand] nor by [handleCmsRequest] (whose
  /// app is the server one, see [cmsSiteOf]).
  bool isAppAllowed(String app) =>
      flavorContext.isProd ? !festenaoIsDevApp(app) : festenaoIsDevApp(app);

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    switch (apiRequest.command.v!) {
      default:
        return super.onCommand(apiRequest);
    }
  }

  @override
  Future<ApiResult> onCronCommand(ApiRequest apiRequest) async {
    var db = FestenaoFirestoreDatabase(
      firebaseContext: firebaseContext,
      flavorContext: appFlavorContext,
    );
    await db.projectDb.purgeDeletedEntities();
    await db.projectDb.deleteOldInvites();
    return ApiEmpty();
  }

  /// Handles HTTPS AMP requests.
  Future<void> onHttpsAmp(ExpressHttpRequest request) async {
    var incomingRequest = IncomingAmpRequest(request: request);
    await onAmp(incomingRequest);
  }

  /// Handles AMP requests.
  Future<void> onAmp(IncomingAmpRequest ampRequest) async {
    var requestPath = ampRequest.path;
    var request = ampRequest.request;
    return onAppAmp(
      IncomingAppAmpRequest(request: request, app: app, path: requestPath),
    );
    /*
    // ignore: dead_code
    var parts = requestPath.split('/');
    var first = parts.first;
    if (first == 'app') {}
    try {
      print('$requestPath: requestPath');

      await sendHtml(request, '''OKd
      ''');
    } catch (e, st) {
      await sendHtml(request, ''''ERROR $e
      $st
      ''');
    }*/
  }

  /// Handles app-specific AMP requests.
  Future<void> onAppAmp(IncomingAppAmpRequest appAmpRequest) async {
    var requestPath = appAmpRequest.path;
    var request = appAmpRequest.request;
    var app = appAmpRequest.app;
    try {
      // print('requestPath: $requestPath');
      var page = FestenaoAmpPage();
      page.consoleAdd('app: $app');
      page.consoleAdd('requestPath: $requestPath');
      await sendHtml(request, await page.build());
    } catch (e, st) {
      var page = FestenaoAmpPage();
      page.consoleAdd('app: $app');
      page.consoleAdd('requestPath: $requestPath');
      page.consoleAdd('Error $e');
      page.consoleAdd('Stack trace $st');
      await sendHtml(request, await page.build());
    }
  }

  /// Gets the AMP HTTPS function.
  HttpsFunction get amp => functions.https.onRequestV2(
    HttpsOptions(cors: true, region: regionBelgium),
    onHttpsAmp,
  );

  // --- Cms sites ---

  /// The mounts of the cms function, a first path segment among them is
  /// stripped: the hosting path ([festenaoCmsHostingPath]) and the function
  /// name ([cmsCommand], kept in front of the path by the local runners).
  List<String> get cmsMountNames => [festenaoCmsHostingPath, cmsCommand];

  /// The schema of the project content databases the cms sites read, only
  /// the pages and the media by default: an app keeping other stores in the
  /// same synced database gives its own schema here.
  SdbOpenDatabaseOptions get cmsContentSdbOptions =>
      festenaoCmsContentSdbOpenOptions;

  /// The project contents the cms sites read.
  late final cmsContentCache = FestenaoCmsContentCache(
    firestore: firestore,
    openOptions: cmsContentSdbOptions,
  );

  /// The site of a request: `<projectId>/<dataId>/...` below the mount, the
  /// ids moved into the base url of the returned request; null when the url
  /// is not the one of a site.
  ///
  /// Override to change the url shape (an app id in front, a default data
  /// id...).
  (FestenaoCmsSiteRef, CmsSiteRequest)? cmsSiteOf(CmsSiteRequest request) {
    var siteRequest = request.shift(2);
    if (siteRequest == null) {
      return null;
    }
    return (
      FestenaoCmsSiteRef(
        app: app,
        projectId: request.segments[0],
        dataId: request.segments[1],
      ),
      siteRequest,
    );
  }

  /// The project of a site, null when it does not exist or is deleted (its
  /// site is then not served).
  Future<FsProject?> cmsSiteProject(FestenaoCmsSiteRef ref) async {
    initFestenaoFsBuilders();
    var project = await CvDocumentReference<FsProject>(
      ref.projectDocumentPath,
    ).get(firestore);
    if (!project.exists || (project.deleted.v ?? false)) {
      return null;
    }
    return project;
  }

  /// The site serving [content], the published pages of the project at
  /// [request] base url, named after the [project].
  ///
  /// Override to customize the site (description, navigation, templates,
  /// page options, image urls...).
  Future<CmsSiteHandler> cmsSiteHandler({
    required FsProject project,
    required FestenaoCmsContent content,
    required CmsSiteRequest request,
  }) async {
    return CmsSiteHandler(
      pages: content.pages,
      renderer: CmsRenderer(
        site: CmsSite(
          name: project.name.v ?? content.ref.projectId,
          baseUrl: request.baseUrl,
        ),
      ),
    );
  }

  /// Serves a request of the cms function, the mount stripped (see
  /// [CmsSiteRequest.fromUrl] and [cmsMountNames]): a 404 when it is not the
  /// url of an existing site.
  Future<CmsResponse> handleCmsRequest(CmsSiteRequest request) async {
    try {
      var site = cmsSiteOf(request);
      if (site == null) {
        return festenaoCmsNotFound;
      }
      var (ref, siteRequest) = site;
      var project = await cmsSiteProject(ref);
      if (project == null) {
        return festenaoCmsNotFound;
      }
      var content = await cmsContentCache.get(ref);
      if (content == null) {
        return festenaoCmsNotFound;
      }
      var handler = await cmsSiteHandler(
        project: project,
        content: content,
        request: siteRequest,
      );
      return await handler.handlePath(siteRequest.path);
    } catch (e) {
      return CmsResponse.text('Error: $e', statusCode: 500);
    }
  }

  /// Handles the cms function (in process / sim / io servers).
  Future<void> onHttpsCms(ExpressHttpRequest request) async {
    var response = await handleCmsRequest(
      CmsSiteRequest.fromUrl(
        expressRequestUrl(request),
        mountNames: cmsMountNames,
        forwardedHost: request.headers.value(httpHeaderXForwardedHost),
        forwardedProto: request.headers.value(httpHeaderXForwardedProto),
      ),
    );
    await sendExpressCmsResponse(request, response);
  }

  /// The cms https function.
  HttpsFunction get cms => functions.https.onRequestV2(
    HttpsOptions(cors: true, region: regionBelgium),
    onHttpsCms,
  );

  /// Registers the cms function ([cmsCommand]) on the express runtimes (io,
  /// node, sim), after [initFunctions]: not done by default, a server
  /// serving no site keeps no such function.
  ///
  /// The dart (admin sdk) runtime registers `functionsCmsDartHandler`
  /// instead (`server/festenao_server_admin_sdk.dart`).
  void initCmsFunction() {
    functions[cmsCommand] = cms;
  }

  @override
  void initFunctions() {
    ampCommand = 'amp${flavorContext.ifNotProdFlavor}';
    super.initFunctions();
    functions[ampCommand] = amp;
  }
}

/// The response when there is no site at a url.
const festenaoCmsNotFound = CmsResponse.text('Not found', statusCode: 404);

/// `x-forwarded-host` header, the host the visitor typed (behind firebase
/// hosting).
const httpHeaderXForwardedHost = 'x-forwarded-host';

/// `x-forwarded-proto` header, the scheme the visitor used.
const httpHeaderXForwardedProto = 'x-forwarded-proto';

/// The headers of a cms response: its content type, and a cdn cache for the
/// pages served.
Map<String, String> festenaoCmsResponseHeaders(CmsResponse response) => {
  'content-type': response.contentType,
  // Static pages, cached by the CDN a few minutes.
  if (response.isOk) 'cache-control': 'public, s-maxage=300, max-age=60',
};

/// The absolute url of an express request, function name included when the
/// runner kept it (io, sim).
Uri expressRequestUrl(ExpressHttpRequest request) {
  // ignore: deprecated_member_use
  var url = request.requestedUri;
  if (url.hasScheme && url.hasAuthority) {
    return url;
  }
  var host = request.headers.value('host') ?? 'localhost';
  return Uri.parse('http://$host').replace(path: url.path, query: url.query);
}

/// Sends [response] on an express request.
Future<void> sendExpressCmsResponse(
  ExpressHttpRequest request,
  CmsResponse response,
) async {
  var res = request.response;
  res.statusCode = response.statusCode;
  festenaoCmsResponseHeaders(response).forEach(res.headers.set);
  await res.send(response.body);
}

/// Incoming request for app-specific AMP.
class IncomingAppAmpRequest extends IncomingAmpRequest {
  /// Creates a new [IncomingAppAmpRequest] with the given [request], [app], and optional [path].
  IncomingAppAmpRequest({
    required super.request,
    required this.app,
    super.path,
  });

  /// The app name.
  final String app;
}

/// Incoming request for AMP.
class IncomingAmpRequest implements AmpRequest {
  /// The HTTP request.
  final ExpressHttpRequest request;

  @override
  late final String path;

  /// The URI of the request.
  Uri get uri => request.uri;

  /// Creates a new [IncomingAmpRequest] with the given [request] and optional [path].
  IncomingAmpRequest({required this.request, String? path}) {
    var requestPath = path ?? uri.path;
    if (requestPath.startsWith('/')) {
      requestPath = requestPath.substring(1);
    }
    this.path = requestPath;
  }
}

/// Extension for [FestenaoServerApp] to initialize entity functions.
extension FesteanoServerAppExt on FestenaoServerApp {
  /// Initializes entity functions for the given [entityHandler].
  void initEntityFunctions<TFsEntity extends TkCmsFsEntity>(
    FestenaoEntityHandler<TkCmsFsEntity> entityHandler,
  ) {}
}

import 'package:festenao_common/amp/amp_page.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tkcms_common/tkcms_server.dart';

import 'festeano_server_entity_handler.dart';

/// Server app for Festenao CMS.
class FestenaoServerApp extends TkAppCmsServerAppBase {
  /// AMP command name.
  late String ampCommand;

  /// Creates a new [FestenaoServerApp] with the given [app], [context], and optional [version].
  FestenaoServerApp({
    String app = 'festenao',
    required super.context,
    super.version,
  }) : super(app, apiVersion: apiVersion2);

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    switch (apiRequest.command.v!) {
      default:
        return super.onCommand(apiRequest);
    }
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
  @override
  void initFunctions() {
    ampCommand = 'amp${flavorContext.ifNotProdFlavor}';
    super.initFunctions();
    functions[ampCommand] = amp;
  }
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

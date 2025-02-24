import 'package:festenao_common/amp/amp_page.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// Our server app
class FestenaoServerApp extends TkCmsServerAppV2 {
  final String app;
  late String ampCommand;
  FestenaoServerApp({this.app = 'festenao', required super.context})
      : super(apiVersion: apiVersion2);

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    switch (apiRequest.command.v!) {
      default:
        return super.onCommand(apiRequest);
    }
  }

  Future<void> onHttpsAmp(ExpressHttpRequest request) async {
    var incomingRequest = IncomingAmpRequest(request: request);
    await onAmp(incomingRequest);
  }

  Future<void> onAmp(IncomingAmpRequest ampRequest) async {
    var requestPath = ampRequest.path;
    var request = ampRequest.request;
    return onAppAmp(
        IncomingAppAmpRequest(request: request, app: app, path: requestPath));
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

  HttpsFunction get amp => functions.https.onRequestV2(
        HttpsOptions(cors: true, region: regionBelgium),
        onHttpsAmp,
      );
  @override
  void initFunctions() {
    ampCommand = 'amp${flavorContext.ifNotProdSuffix}';
    super.initFunctions();
    functions[ampCommand] = amp;
  }
}

class IncomingAppAmpRequest extends IncomingAmpRequest {
  IncomingAppAmpRequest(
      {required super.request, required this.app, super.path});

  final String app;
}

class IncomingAmpRequest implements AmpRequest {
  final ExpressHttpRequest request;
  @override
  late final String path;
  Uri get uri => request.uri;
  IncomingAmpRequest({required this.request, String? path}) {
    var requestPath = path ?? uri.path;
    if (requestPath.startsWith('/')) {
      requestPath = requestPath.substring(1);
    }
    this.path = requestPath;
  }
}

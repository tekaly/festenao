@TestOn('vm')
library;

import 'dart:async';

import 'package:festenao_dartff/functions.dart';
import 'package:festenao_demo/festenao_demo_cms.dart';
import 'package:tekartik_http/http_memory.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// The cms functions, as the deployed dart functions run them (the admin sdk
/// http runner), served in memory: no emulator, no network.
///
/// - `cmsdev`: the sites of the projects of a dev [FfApp], here the demo
///   project seeded in an in memory firestore.
/// - `cmsdemo`: the hard coded demo site.
void main() {
  late FirebaseContext firebaseContext;
  late FfApp ffApp;
  late HttpServer httpServer;
  late Uri serverUri;
  var printed = <String>[];
  var client = httpFactoryMemory.client.newClient();

  setUpAll(() async {
    firebaseContext = initFirebaseServicesLocalMemory(
      projectId: 'cms-function-test',
    ).initContext();
    firebaseContextOrNull = firebaseContext;
    ffApp = FfApp(
      context: TkCmsServerAppContext(
        firebaseContext: firebaseContext,
        flavorContext: FlavorContext.dev,
      ),
    );
    await fillDemoCmsProject(
      firestore: firebaseContext.firestore,
      app: ffApp.app,
    );

    // The shared helpers the standalone servers use, on a memory server.
    var functions = await runZoned(
      () => serveFestenaoFunctionsHttp(
        httpServerFactory: httpFactoryMemory.server,
        firebaseApp: firebaseContext.firebaseApp,
        declare: (functions) {
          declareRunner(ffApp, functions);
          declareCmsDemoRunner(functions);
        },
      ),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => printed.add(line),
      ),
    );
    httpServer = functions.httpServer;
    serverUri = httpServerGetUri(httpServer);
  });

  tearDownAll(() async {
    client.close();
    await httpServer.close(force: true);
    await ffApp.cmsContentCache.close();
  });

  Future<({int statusCode, Map<String, String> headers, String body})> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    var response = await client.get(serverUri.resolve(path), headers: headers);
    return (
      statusCode: response.statusCode,
      headers: response.headers,
      body: response.body,
    );
  }

  test('served on the festenao port, listed as such', () {
    expect(httpServer.port, festenaoFunctionsHttpServerPort);
    expect(printed, contains('cmsdev http://localhost:8040/cmsdev'));
    expect(printed, contains('cmsdemo http://localhost:8040/cmsdemo'));
  });

  group('cmsdev', () {
    var siteUrl = '/cmsdev/$demoCmsProjectId/$demoCmsDataId/';

    test('index', () async {
      var response = await get(siteUrl);
      expect(response.statusCode, 200, reason: response.body);
      expect(response.headers['content-type'], cmsContentTypeHtml);
      expect(response.headers['cache-control'], contains('s-maxage'));
      expect(response.body, contains(demoCmsSiteName));
      expect(response.body, contains('About the festival'));
      expect(response.body, isNot(contains('Line-up 2027')));
      // Page links are under the site url.
      expect(
        response.body,
        contains('href="${serverUri.resolve(siteUrl)}page/about"'),
      );
    });

    test('page, sitemap', () async {
      var response = await get('${siteUrl}page/about');
      expect(response.statusCode, 200);
      expect(response.body, contains('<h1>About the festival</h1>'));
      var sitemap = await get('${siteUrl}sitemap.xml');
      expect(sitemap.headers['content-type'], cmsContentTypeXml);
      expect(sitemap.body, contains('${siteUrl}page/program</loc>'));
    });

    test('behind the hosting, the links use the forwarded host', () async {
      var response = await get(
        siteUrl,
        headers: {
          'x-forwarded-host': 'festenao-app-dev.web.app',
          'x-forwarded-proto': 'https',
        },
      );
      expect(
        response.body,
        contains(
          'href="https://festenao-app-dev.web.app$siteUrl'
          'page/about"',
        ),
      );
    });

    test('not found', () async {
      for (var path in [
        '/cmsdev/',
        '/cmsdev/$demoCmsProjectId/',
        '/cmsdev/$demoCmsProjectId/other/',
        '/cmsdev/unknown/$demoCmsDataId/',
        '${siteUrl}page/line-up-2027',
      ]) {
        var response = await get(path);
        expect(response.statusCode, 404, reason: path);
        expect(response.headers['cache-control'], isNull);
      }
    });
  });

  group('cmsdemo', () {
    test('index', () async {
      var response = await get('/cmsdemo/');
      expect(response.statusCode, 200);
      expect(response.body, contains(demoCmsSiteName));
      expect(
        response.body,
        contains('href="${serverUri.resolve('/cmsdemo/')}page/about"'),
      );
    });

    test('event page, with its structured data', () async {
      var response = await get('/cmsdemo/page/opening-night-concert');
      expect(response.statusCode, 200);
      expect(response.body, contains('"@type":"Event"'));
    });

    test('draft not found', () async {
      expect((await get('/cmsdemo/page/line-up-2027')).statusCode, 404);
    });
  });
}

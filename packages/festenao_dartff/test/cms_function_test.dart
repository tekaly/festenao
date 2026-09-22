@TestOn('vm')
library;

import 'dart:async';

import 'package:festenao_common/festenao_cms.dart';
import 'package:festenao_dartff/functions.dart';
import 'package:tekartik_http/http_memory.dart';
import 'package:test/test.dart';

/// The cms function, as the deployed dart functions run it (the admin sdk
/// http runner), served in memory: no emulator, no network.
void main() {
  const functionName = 'cmsdev';
  late SdbDatabase db;
  late CmsPageSdb pages;
  late HttpServer httpServer;
  late Uri functionUri;
  var printed = <String>[];
  var client = httpFactoryMemory.client.newClient();

  setUpAll(() async {
    db = await newSdbFactoryMemory().openDatabase(
      'cms_function_test.db',
      options: SdbOpenDatabaseOptions(
        version: 1,
        schema: SdbDatabaseSchema(stores: [cmsPageStoreSchema]),
      ),
    );
    pages = CmsPageSdb(db: db);
    await pages.addPage(
      SdbCmsPage()
        ..title.v = 'About the festival'
        ..summary.v = 'Three days of music'
        ..body.v = '# Welcome\n\nSee the [program](program).'
        ..published.v = true,
    );
    await pages.addPage(SdbCmsPage()..title.v = 'Draft line-up');

    // The shared helpers the standalone servers use, on a memory server.
    var functions = await runZoned(
      () => serveFestenaoFunctionsHttp(
        httpServerFactory: httpFactoryMemory.server,
        declare: (functions) => declareCmsSiteRunner(
          functions,
          name: functionName,
          // The site lives under the function url, known once served.
          siteHandler: () => CmsSiteHandler(
            pages: pages,
            renderer: CmsRenderer(
              site: CmsSite(
                name: 'Festenao festival',
                baseUrl: functionUri,
                language: 'en',
              ),
            ),
          ),
        ),
      ),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => printed.add(line),
      ),
    );
    httpServer = functions.httpServer;
    functionUri = httpServerGetUri(httpServer).replace(path: '/$functionName/');
  });

  tearDownAll(() async {
    client.close();
    await httpServer.close(force: true);
    await db.close();
  });

  Future<({int statusCode, Map<String, String> headers, String body})> get(
    String path,
  ) async {
    var response = await client.get(functionUri.resolve(path));
    return (
      statusCode: response.statusCode,
      headers: response.headers,
      body: response.body,
    );
  }

  test('served on the festenao port, listed as such', () {
    expect(httpServer.port, festenaoFunctionsHttpServerPort);
    expect(functionUri.port, 8040);
    expect(printed, contains('cmsdev http://localhost:8040/cmsdev'));
  });

  test('index', () async {
    var response = await get('');
    expect(response.statusCode, 200);
    expect(response.headers['content-type'], cmsContentTypeHtml);
    expect(response.headers['cache-control'], contains('s-maxage'));
    expect(response.body, contains('About the festival'));
    expect(response.body, isNot(contains('Draft line-up')));
    // Page links are under the function url.
    expect(
      response.body,
      contains('href="${functionUri}page/about-the-festival"'),
    );
  });

  test('page', () async {
    var response = await get('page/about-the-festival');
    expect(response.statusCode, 200);
    expect(response.body, contains('<h1>About the festival</h1>'));
    expect(
      response.body,
      contains('<meta name="description" content="Three days of music">'),
    );
    expect(response.body, contains('"@type":"WebPage"'));
  });

  test('sitemap and robots', () async {
    var sitemap = await get('sitemap.xml');
    expect(sitemap.statusCode, 200);
    expect(sitemap.headers['content-type'], cmsContentTypeXml);
    expect(
      sitemap.body,
      contains('<loc>${functionUri}page/about-the-festival</loc>'),
    );
    var robots = await get('robots.txt');
    expect(robots.headers['content-type'], cmsContentTypeText);
    expect(robots.body, contains('Sitemap: ${functionUri}sitemap.xml'));
  });

  test('not found, drafts included', () async {
    for (var path in ['page/unknown', 'page/draft-line-up', 'other']) {
      var response = await get(path);
      expect(response.statusCode, 404, reason: path);
      expect(response.headers['cache-control'], isNull);
      expect(response.body, contains('noindex'));
    }
  });

  test('a change is served at once', () async {
    var draft = (await pages.getPageBySlug('draft-line-up'))!;
    await pages.setPublished(draft.id, true);
    addTearDown(() => pages.setPublished(draft.id, false));
    expect((await get('page/draft-line-up')).statusCode, 200);
    expect((await get('')).body, contains('Draft line-up'));
  });
}

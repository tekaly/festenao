import 'package:festenao_demo/festenao_demo_cms.dart';
import 'package:test/test.dart';

void main() {
  group('demo cms', () {
    late DemoCms cms;

    setUpAll(() async {
      cms = await DemoCms.create();
    });
    tearDownAll(() async {
      await cms.database.close();
    });

    test('pages', () async {
      var pages = await cms.pages.getPages();
      expect(pages.length, demoCmsPages().length);
      expect(pages.map((page) => page.slug.v), contains('about'));
      var published = await cms.pages.getPages(publishedOnly: true);
      expect(
        published.map((page) => page.slug.v),
        isNot(contains('line-up-2027')),
      );
    });

    test('site', () {
      expect(cms.renderer.site.baseUrl, demoCmsBaseUrl);
      expect(cms.renderer.site.nav.first.url, 'https://festival.example.com/');
    });
  });

  group('demo cms server', () {
    var server = DemoCmsServer();
    tearDownAll(() => server.close());

    Future<CmsResponse> get(String url, {List<String> mountNames = const []}) =>
        server.handle(
          CmsSiteRequest.fromUrl(Uri.parse(url), mountNames: mountNames),
        );

    test('the links follow the url of the request', () async {
      var response = await get(
        'https://hosting.example.com/cmsdemo/',
        mountNames: ['cmsdemo'],
      );
      expect(response.statusCode, 200);
      expect(response.isHtml, isTrue);
      expect(response.body, contains('Festenao summer festival'));
      expect(
        response.body,
        contains('href="https://hosting.example.com/cmsdemo/page/about"'),
      );

      response = await get('http://localhost:8040/page/about');
      expect(response.statusCode, 200);
      expect(response.body, contains('<h1>About the festival</h1>'));
      expect(
        response.body,
        contains('href="http://localhost:8040/page/program"'),
      );
    });

    test('event structured data', () async {
      var response = await get(
        'https://hosting.example.com/page/opening-night-concert',
      );
      expect(response.body, contains('"@type":"Event"'));
    });

    test('sitemap, not found', () async {
      var sitemap = await get('https://hosting.example.com/sitemap.xml');
      expect(sitemap.statusCode, 200);
      expect(sitemap.body, contains('/page/about</loc>'));
      expect(sitemap.body, isNot(contains('legal')));
      for (var path in ['page/line-up-2027', 'page/unknown', 'other']) {
        var response = await get('https://hosting.example.com/$path');
        expect(response.statusCode, 404, reason: path);
      }
    });
  });
}

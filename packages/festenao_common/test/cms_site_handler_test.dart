import 'package:festenao_common/festenao_cms.dart';
import 'package:test/test.dart';

void main() {
  group('CmsSiteHandler', () {
    late SdbDatabase db;
    late CmsPageSdb pageSdb;
    var site = CmsSite(
      name: 'Festival',
      baseUrl: Uri.parse('https://example.com/app/fest/'),
      language: 'en',
    );
    var renderer = CmsRenderer(site: site);

    setUp(() async {
      db = await newSdbFactoryMemory().openDatabase(
        'cms_site_test.db',
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [cmsPageStoreSchema]),
        ),
      );
      pageSdb = CmsPageSdb(db: db);
      await pageSdb.addPage(
        SdbCmsPage()
          ..title.v = 'About us'
          ..body.v = '# About\n\nSee [the program](/page/program).'
          ..published.v = true,
      );
      await pageSdb.addPage(
        SdbCmsPage()
          ..title.v = 'Program'
          ..published.v = true,
      );
      await pageSdb.addPage(SdbCmsPage()..title.v = 'Secret draft');
    });
    tearDown(() async {
      await db.close();
    });

    test('pathOf', () {
      var handler = CmsSiteHandler(pages: pageSdb, renderer: renderer);
      expect(handler.pathOf(Uri.parse('https://example.com/app/fest/')), '');
      expect(handler.pathOf(Uri.parse('https://example.com/app/fest')), '');
      expect(
        handler.pathOf(Uri.parse('https://example.com/app/fest/page/about/')),
        'page/about',
      );
      expect(
        handler.pathOf(Uri.parse('https://example.com/app/fest/page/a%20b')),
        'page/a b',
      );
      // Relative urls are below the base url.
      expect(handler.pathOf(Uri.parse('/page/about')), 'page/about');
      expect(handler.pathOf(Uri.parse('sitemap.xml')), 'sitemap.xml');
      // Not on the site.
      expect(handler.pathOf(Uri.parse('https://other.com/app/fest/')), isNull);
      expect(
        handler.pathOf(Uri.parse('https://example.com/app/other')),
        isNull,
      );
      expect(handler.pathOf(Uri.parse('http://example.com/app/fest/')), isNull);
      expect(
        handler.urlOf('page/about'),
        'https://example.com/app/fest/page/about',
      );
    });

    test('index, pages, sitemap, robots', () async {
      var handler = CmsSiteHandler(pages: pageSdb, renderer: renderer);

      var index = await handler.handlePath('');
      expect(index.statusCode, 200);
      expect(index.isHtml, isTrue);
      expect(
        index.body,
        contains('https://example.com/app/fest/page/about-us'),
      );
      expect(index.body, contains('Program'));
      expect(index.body, isNot(contains('Secret draft')));

      var page = await handler.handleUrl(
        Uri.parse('https://example.com/app/fest/page/about-us'),
      );
      expect(page.statusCode, 200);
      expect(page.body, contains('<h1>About us</h1>'));
      expect(page.body, isNot(contains('noindex')));

      var sitemap = await handler.handlePath('/sitemap.xml');
      expect(sitemap.contentType, cmsContentTypeXml);
      expect(
        sitemap.body,
        contains('<loc>https://example.com/app/fest/page/program</loc>'),
      );
      expect(sitemap.body, isNot(contains('secret-draft')));

      var robots = await handler.handlePath('robots.txt');
      expect(robots.contentType, cmsContentTypeText);
      expect(robots.body, contains('Sitemap: https://example.com/app/fest/'));
    });

    test('not found', () async {
      var handler = CmsSiteHandler(pages: pageSdb, renderer: renderer);
      for (var path in [
        'page/unknown',
        'page/',
        'other',
        'page/secret-draft',
      ]) {
        var response = await handler.handlePath(path);
        expect(response.statusCode, 404, reason: path);
        expect(response.isOk, isFalse);
        expect(response.body, contains('noindex'));
      }
      expect(
        (await handler.handleUrl(Uri.parse('https://other.com/'))).statusCode,
        404,
      );
    });

    test('drafts', () async {
      var handler = CmsSiteHandler(
        pages: pageSdb,
        renderer: renderer,
        includeDrafts: true,
      );
      var draft = await handler.handlePath('page/secret-draft');
      expect(draft.statusCode, 200);
      expect(draft.body, contains('<h1>Secret draft</h1>'));
      // Never indexed.
      expect(draft.body, contains('<meta name="robots" content="noindex'));
      // Still out of the index and the sitemap.
      expect((await handler.handlePath('')).body, isNot(contains('Secret')));
      expect(
        (await handler.handlePath('sitemap.xml')).body,
        isNot(contains('secret-draft')),
      );
      // The record itself is left as it is.
      expect((await pageSdb.getPageBySlug('secret-draft'))!.noIndex.v, isNull);
    });

    test('page options and page path prefix', () async {
      var handler = CmsSiteHandler(
        pages: pageSdb,
        renderer: CmsRenderer(
          site: CmsSite(
            name: 'Root',
            baseUrl: Uri.parse('https://example.com/'),
            pagePathPrefix: '',
          ),
        ),
        pageOptions: (page) => CmsPageRenderOptions(
          details: [CmsPageDetail(label: 'Slug', value: page.slug.v!)],
        ),
      );
      var page = await handler.handlePath('program');
      expect(page.statusCode, 200);
      expect(page.body, contains('<dt>Slug</dt><dd>program</dd>'));
      expect((await handler.handlePath('sitemap.xml')).isOk, isTrue);
      expect(
        handler.pathOf(Uri.parse('https://example.com/program')),
        'program',
      );
    });
  });
}

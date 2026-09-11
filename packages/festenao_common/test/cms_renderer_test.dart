import 'package:festenao_common/festenao_cms.dart';
import 'package:test/test.dart';

void main() {
  initFestenaoCmsBuilders();
  var site = CmsSite(
    name: 'My <Site>',
    baseUrl: Uri.parse('https://example.com/app/cal1/'),
    language: 'en',
    description: 'Site description',
    nav: const [CmsNavLink(label: 'Home', url: '/')],
  );
  var renderer = CmsRenderer(site: site);

  SdbCmsPage newPage() => SdbCmsPage()
    ..slug.v = 'the-lake'
    ..title.v = 'The Lake & the "boats"'
    ..summary.v = 'A nice lake'
    ..body.v = '# Welcome\n\nSome *markdown* text.\n\n<script>alert(1)</script>'
    ..heroImage.v = (CvCmsImage()
      ..url.v = 'https://img.example.com/lake.jpg'
      ..alt.v = 'Lake')
    ..tags.v = ['nature', 'water']
    ..published.v = true
    ..publishedAt.v = SdbTimestamp.fromMillisecondsSinceEpoch(
      DateTime.utc(2026, 9, 1).millisecondsSinceEpoch,
    );

  test('markdown', () {
    expect(cmsMarkdownToHtml('# Hi\n\n**b**'), contains('>Hi</h1>'));
    expect(cmsMarkdownToHtml('a **b**'), contains('<strong>b</strong>'));
    expect(
      cmsMarkdownExcerpt(
        '# Title\n\nSome [link](http://x) and ![img](y) text.',
      ),
      'Title Some link and text.',
    );
    expect(
      cmsMarkdownExcerpt('word ' * 100, maxLength: 20).length,
      lessThan(25),
    );
  });

  test('site urls', () {
    expect(site.baseUrlText, 'https://example.com/app/cal1');
    expect(site.url(''), 'https://example.com/app/cal1/');
    expect(site.pageUrl('x'), 'https://example.com/app/cal1/page/x');
  });

  test('renderPage', () async {
    var html = await renderer.renderPage(newPage());
    expect(html, startsWith('<!DOCTYPE html>'));
    expect(html, contains('<html lang="en">'));
    // Escaped title in the head and the body.
    expect(
      html,
      contains('<title>The Lake &amp; the &quot;boats&quot;</title>'),
    );
    expect(html, contains('<h1>The Lake &amp; the &quot;boats&quot;</h1>'));
    expect(html, contains('<meta name="description" content="A nice lake">'));
    expect(
      html,
      contains(
        '<link rel="canonical" href="https://example.com/app/cal1/page/the-lake">',
      ),
    );
    expect(
      html,
      contains(
        'property="og:image" content="https://img.example.com/lake.jpg"',
      ),
    );
    // Markdown rendered, raw html in markdown escaped by the markdown renderer.
    expect(html, contains('>Welcome</h1>'));
    expect(html, contains('<em>markdown</em>'));
    // JSON-LD present.
    expect(html, contains('<script type="application/ld+json">'));
    expect(html, contains('"@type":"WebPage"'));
    expect(html, contains('"datePublished":"2026-09-01"'));
    expect(html, contains('<span class="tag">nature</span>'));
    expect(html, contains('<time datetime="2026-09-01">'));
    expect(html, contains('My &lt;Site&gt;'));
  });

  test('renderPage with options', () async {
    var page = newPage()..noIndex.v = true;
    var html = await renderer.renderPage(
      page,
      options: CmsPageRenderOptions(
        ogType: 'event',
        details: const [CmsPageDetail(label: 'Price', value: '10 €')],
        structuredData: CmsStructuredData.event(
          name: 'Concert',
          startDate: '2026-10-01T20:00:00Z',
          location: 'The Lake',
          offers: [CmsStructuredData.offer(price: 10, currency: 'EUR')],
        ),
      ),
    );
    expect(html, contains('<meta name="robots" content="noindex, nofollow">'));
    expect(html, contains('<meta property="og:type" content="event">'));
    expect(html, contains('<dt>Price</dt><dd>10 €</dd>'));
    expect(html, contains('"@type":"Event"'));
    expect(html, contains('"priceCurrency":"EUR"'));
  });

  test('renderIndex/notFound/sitemap/robots', () async {
    var page = newPage();
    var html = await renderer.renderIndex([page], path: '');
    expect(html, contains('<title>My &lt;Site&gt;</title>'));
    expect(html, contains('href="https://example.com/app/cal1/page/the-lake"'));
    expect(html, contains('<h2>The Lake &amp; the &quot;boats&quot;</h2>'));
    var empty = await renderer.renderIndex([], title: 'Empty');
    expect(empty, contains('Nothing published yet.'));

    var notFound = await renderer.renderNotFound();
    expect(notFound, contains('Page not found'));
    expect(notFound, contains('noindex'));

    var sitemap = renderer.renderSitemap([
      page,
      newPage()..published.v = false,
    ]);
    expect(sitemap, contains('<loc>https://example.com/app/cal1/</loc>'));
    expect(
      sitemap,
      contains('<loc>https://example.com/app/cal1/page/the-lake</loc>'),
    );
    expect('<loc>'.allMatches(sitemap).length, 2);

    expect(
      renderer.renderRobots(),
      contains('Sitemap: https://example.com/app/cal1/sitemap.xml'),
    );
  });

  test('json-ld escaping', () {
    expect(
      CmsStructuredData.toJsonLd({'x': '</script><script>'}),
      r'{"x":"<\/script><script>"}',
    );
    expect(CmsStructuredData.place(name: 'P', description: ''), {
      '@context': 'https://schema.org',
      '@type': 'Place',
      'name': 'P',
    });
  });
}

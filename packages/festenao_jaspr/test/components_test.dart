/// Server rendering of the components, as `jaspr build` does.
///
/// The vm only: server rendering and `dart:io` (the CI also runs the
/// package's tests in a browser).
@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_jaspr/server.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_test/server_test.dart';
import 'package:path/path.dart';

const _url = 'https://example.youpi.app';

/// The rendered page of [body] and [head], parsed.
Future<DocumentResponse> _render(
  ServerTester tester, {
  List<Component> body = const [],
}) async {
  tester.pumpComponent(
    siteDocument(
      title: 'Example',
      cssPath: null,
      body: Component.fragment(body),
    ),
  );
  var response = await tester.request('/');
  expect(response.statusCode, 200);
  return response;
}

void main() {
  setUpAll(() {
    Jaspr.initializeApp(options: const ServerOptions());
  });

  group('SiteHead', () {
    testServer('a page in two languages', (tester) async {
      var response = await _render(
        tester,
        body: [
          const SiteHead(
            SiteHeadData(
              lang: SiteLang.fr,
              siteName: 'Youpi',
              title: 'Youpi, des applis',
              description: 'Petites applis.',
              url: '$_url/fr/',
              alternates: {SiteLang.en: '$_url/', SiteLang.fr: '$_url/fr/'},
              image: SiteImage(
                url: '$_url/og/fr.png',
                width: 1200,
                height: 630,
                alt: 'Les applis',
              ),
              jsonLd: {'@type': 'Organization', 'name': '</script>'},
            ),
          ),
        ],
      );
      var document = response.document!;
      expect(document.querySelector('title')?.text, 'Youpi, des applis');
      expect(
        document.querySelector('link[rel="canonical"]')?.attributes['href'],
        '$_url/fr/',
      );
      var alternates = {
        for (var link in document.querySelectorAll('link[rel="alternate"]'))
          link.attributes['hreflang']: link.attributes['href'],
      };
      expect(alternates, {
        'en': '$_url/',
        'fr': '$_url/fr/',
        'x-default': '$_url/',
      });
      expect(document.querySelector('meta[name="robots"]'), isNull);
      String? property(String name) => document
          .querySelector('meta[property="$name"]')
          ?.attributes['content'];
      expect(property('og:url'), '$_url/fr/');
      expect(property('og:locale'), 'fr_FR');
      expect(property('og:locale:alternate'), 'en_US');
      expect(property('og:image:width'), '1200');
      expect(
        document
            .querySelector('meta[name="twitter:card"]')
            ?.attributes['content'],
        'summary_large_image',
      );
      expect(response.body, contains(r'"name":"<\/script>"'));
    });

    testServer('a 404 page: noindex, no canonical, no hreflang', (
      tester,
    ) async {
      var response = await _render(
        tester,
        body: [
          const SiteHead(
            SiteHeadData(
              lang: SiteLang.en,
              siteName: 'Youpi',
              title: 'Page not found',
              description: 'Not here.',
              noIndex: true,
            ),
          ),
        ],
      );
      var document = response.document!;
      expect(
        document.querySelector('meta[name="robots"]')?.attributes['content'],
        'noindex, nofollow',
      );
      expect(document.querySelector('link[rel="canonical"]'), isNull);
      expect(document.querySelectorAll('link[rel="alternate"]'), isEmpty);
      expect(document.querySelector('meta[property="og:url"]'), isNull);
      expect(
        document
            .querySelector('meta[name="twitter:card"]')
            ?.attributes['content'],
        'summary',
      );
    });
  });

  testServer('LanguageLink', (tester) async {
    var response = await _render(
      tester,
      body: [
        const LanguageLink(
          to: SiteLang.fr,
          href: '/fr/',
          cookieDomain: 'youpi.app',
        ),
      ],
    );
    var link = response.document!.querySelector('a.lang-switch')!;
    expect(link.text, 'Français');
    expect(link.attributes['href'], '/fr/');
    expect(link.attributes['hreflang'], 'fr');
    expect(link.attributes['lang'], 'fr');
    expect(
      link.attributes['onclick'],
      languageCookieScript(SiteLang.fr, cookieDomain: 'youpi.app'),
    );
  });

  testServer('rich text and FAQ', (tester) async {
    var response = await _render(
      tester,
      body: [
        const FaqList(
          items: [
            (
              id: 'account',
              question: 'Do I need an account?',
              answer: 'No. Tap **Create** or read [the guide](/guide/).',
            ),
          ],
        ),
      ],
    );
    var faq = response.document!.querySelector('details#faq-account')!;
    expect(faq.querySelector('summary')?.text, 'Do I need an account?');
    expect(faq.querySelector('strong')?.text, 'Create');
    expect(faq.querySelector('a')?.attributes['href'], '/guide/');
    expect(
      faq.querySelector('.faq-answer p')?.text,
      'No. Tap Create or read the guide.',
    );
  });

  testServer('images and store badges', (tester) async {
    var response = await _render(
      tester,
      body: [
        siteImage(
          src: '/apps/a.webp',
          src2x: '/apps/a@2x.webp',
          alt: 'A',
          width: 96,
          height: 96,
        ),
        const StoreBadges(
          lang: SiteLang.fr,
          playStoreUrl: 'https://play.google.com/store/apps/details?id=x',
          appStoreUrl: 'https://apps.apple.com/app/x/id1',
        ),
      ],
    );
    var document = response.document!;
    var image = document.querySelector('img[alt="A"]')!;
    expect(image.attributes['srcset'], '/apps/a.webp 1x, /apps/a@2x.webp 2x');
    expect(image.attributes['loading'], 'lazy');
    expect(image.attributes['width'], '96');
    var badges = document.querySelectorAll('.badges img');
    expect(badges.map((badge) => badge.attributes['src']), [
      '/badges/google-play-fr.png',
      '/badges/app-store-fr.svg',
    ]);
    expect(badges.last.attributes['width'], '152');
  });

  group('server', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('festenao_jaspr_test');
    });
    tearDown(() async {
      await dir.delete(recursive: true);
    });

    testServer('markdown file and inlined stylesheet', (tester) async {
      var markdown = join(dir.path, 'notice.en.md');
      File(
        markdown,
      ).writeAsStringSync('# Legal notice\n\nPublished by **Tekartik**.\n');
      var css = join(dir.path, 'site.css');
      File(css).writeAsStringSync('body{margin:0}');
      tester.pumpComponent(
        siteDocument(
          title: 'Example',
          themeColor: '#ffffff',
          preloadFonts: ['/fonts/poppins-regular.woff2'],
          cssPath: css,
          body: MarkdownFile(markdown, classes: 'legal'),
        ),
      );
      var response = await tester.request('/');
      var document = response.document!;
      expect(document.querySelector('.legal h1')?.text, 'Legal notice');
      expect(document.querySelector('.legal strong')?.text, 'Tekartik');
      expect(document.querySelector('style')?.text, 'body{margin:0}');
      expect(
        document
            .querySelector('meta[name="theme-color"]')
            ?.attributes['content'],
        '#ffffff',
      );
      expect(
        document.querySelector('link[rel="preload"]')?.attributes['href'],
        '/fonts/poppins-regular.woff2',
      );
    });
  });
}

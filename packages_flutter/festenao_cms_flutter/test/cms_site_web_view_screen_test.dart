@TestOn('vm')
library;

import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cms_pages_screen_test.dart' show openTestSdb, pumpUntil;

final _renderer = CmsRenderer(
  site: CmsSite(
    name: 'Test festival',
    baseUrl: Uri.parse('https://fest.example.com/'),
    language: 'en',
  ),
);

void main() {
  group('cmsHtmlForBrowser', () {
    var url = Uri.parse('https://fest.example.com/page/a?b=1&c=2');

    test('html gets a base', () {
      var html = cmsHtmlForBrowser(
        const CmsResponse.html(
          '<!DOCTYPE html>\n<html lang="en">\n<HEAD>\n<title>A</title>',
        ),
        url,
      );
      expect(
        html,
        '<!DOCTYPE html>\n<html lang="en">\n<HEAD>'
        '<base href="https://fest.example.com/page/a?b=1&amp;c=2">'
        '\n<title>A</title>',
      );
      // No head: in front.
      expect(
        cmsHtmlForBrowser(const CmsResponse.html('<p>x</p>'), url),
        startsWith('<base href='),
      );
    });

    test('text is preformatted, its urls linked', () {
      var html = cmsHtmlForBrowser(
        const CmsResponse.text('Sitemap: https://fest.example.com/sitemap.xml'),
        Uri.parse('https://fest.example.com/robots.txt'),
      );
      expect(html, contains('<title>robots.txt</title>'));
      expect(
        html,
        contains(
          '<pre>Sitemap: <a href="https://fest.example.com/sitemap.xml">'
          'https://fest.example.com/sitemap.xml</a></pre>',
        ),
      );
    });
  });

  testWidgets('the controller follows the pages and its history', (
    tester,
  ) async {
    var sdb = await openTestSdb(tester, 'controller.db');
    late CmsSiteBrowserController controller;
    await tester.runAsync(() async {
      var page = await sdb.addPage(
        SdbCmsPage()
          ..title.v = 'About'
          ..published.v = true,
      );
      await sdb.addPage(SdbCmsPage()..title.v = 'Draft');
      controller = CmsSiteBrowserController(pages: sdb, renderer: _renderer);
      addTearDown(controller.dispose);
      Future<void> settle() async {
        for (var i = 0; i < 10 && controller.isLoading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      await settle();
      expect(controller.path, '');
      expect(controller.response!.statusCode, 200);
      expect(controller.canGoBack, isFalse);

      controller.go('page/about');
      await settle();
      expect(controller.page!.id, page.id);
      expect(controller.document!.title, 'About');
      expect(controller.url, Uri.parse('https://fest.example.com/page/about'));

      // A draft is served once the drafts are.
      controller.go('page/draft');
      await settle();
      expect(controller.response!.statusCode, 404);
      controller.includeDrafts = true;
      await settle();
      expect(controller.response!.statusCode, 200);
      expect(controller.document!.isNoIndex, isTrue);

      controller.back();
      await settle();
      expect(controller.path, 'page/about');
      expect(controller.canGoForward, isTrue);

      // A change to the pages renders the current one again.
      await sdb.updatePage(page.id, (page) => page.title.v = 'About us');
      for (var i = 0; i < 20 && controller.document!.title != 'About us'; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(controller.document!.title, 'About us');
    });
  });

  testWidgets('elsewhere than on the web, no browser rendering', (
    tester,
  ) async {
    expect(cmsHtmlFrameSupported, isFalse);
    expect(cmsOpenHtmlWindow(), isNull);
    var sdb = await openTestSdb(tester, 'web_view.db');
    late CmsSiteBrowserController controller;
    await tester.runAsync(() async {
      await sdb.addPage(
        SdbCmsPage()
          ..title.v = 'About'
          ..published.v = true,
      );
      controller = CmsSiteBrowserController(pages: sdb, renderer: _renderer);
    });
    addTearDown(controller.dispose);
    expect(cmsSiteOpenInNewTab(controller), isFalse);

    // The flutter browser offers no browser rendering...
    await tester.pumpWidget(
      MaterialApp(
        home: cmsPageSdbScope(
          sdb: sdb,
          child: CmsSiteBrowserScreen(renderer: _renderer),
        ),
      ),
    );
    await pumpUntil(tester, find.text('200 · text/html'));
    expect(find.byTooltip('Browser rendering'), findsNothing);

    // ...and the web view screen, given anyway, says why.
    await tester.pumpWidget(
      MaterialApp(home: CmsSiteWebViewScreen(controller: controller)),
    );
    await pumpUntil(tester, find.text('200 · text/html'));
    expect(
      find.text('The browser rendering is only available on the web.'),
      findsOneWidget,
    );
    expect(find.text('Browser rendering'), findsOneWidget);
    // Its address bar drives the session all the same.
    await tester.enterText(find.byType(TextField), '/page/about');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpUntil(
      tester,
      find.descendant(of: find.byType(AppBar), matching: find.text('About')),
    );
    expect(controller.path, 'page/about');
  });
}

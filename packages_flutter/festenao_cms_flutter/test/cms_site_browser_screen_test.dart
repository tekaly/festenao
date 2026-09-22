import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cms_pages_screen_test.dart' show openTestSdb, pumpUntil;

final _renderer = CmsRenderer(
  site: CmsSite(
    name: 'Test festival',
    baseUrl: Uri.parse('https://fest.example.com/'),
    language: 'en',
    nav: const [
      CmsNavLink(label: 'Home', url: 'https://fest.example.com/'),
      CmsNavLink(label: 'About', url: 'https://fest.example.com/page/about'),
    ],
  ),
);

/// Text of the rendered html, which draws its paragraphs as rich text.
Finder _html(String text) => find.text(text, findRichText: true);

/// The text of the address bar.
String _address(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

Future<CmsPageSdb> _openSite(WidgetTester tester) async {
  var sdb = await openTestSdb(tester, 'site.db');
  await tester.runAsync(() async {
    await sdb.addPage(
      SdbCmsPage()
        ..title.v = 'About'
        ..summary.v = 'Who we are'
        ..body.v =
            '# Hello\n\nSee [the program](/page/program) '
            'or [elsewhere](https://other.example.com/).'
        ..order.v = 1
        ..published.v = true,
    );
    await sdb.addPage(
      SdbCmsPage()
        ..title.v = 'Program'
        ..summary.v = 'What is on'
        ..order.v = 2
        ..published.v = true,
    );
    await sdb.addPage(SdbCmsPage()..title.v = 'Hidden draft');
  });
  return sdb;
}

Future<void> _pumpBrowser(
  WidgetTester tester,
  CmsPageSdb sdb, {
  String initialPath = '',
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: cmsPageSdbScope(
        sdb: sdb,
        child: CmsSiteBrowserScreen(
          renderer: _renderer,
          initialPath: initialPath,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('navigates the rendered site', (tester) async {
    var sdb = await _openSite(tester);
    await _pumpBrowser(tester, sdb);

    // The index: the site title, and a card per published page.
    await pumpUntil(tester, find.text('Who we are'));
    expect(find.text('What is on'), findsOneWidget);
    expect(find.text('Hidden draft'), findsNothing);
    expect(_address(tester), 'https://fest.example.com/');
    expect(find.text('200 · text/html'), findsOneWidget);

    // A card opens its page.
    await tester.tap(find.text('Who we are'));
    await pumpUntil(tester, _html('Hello'));
    expect(_address(tester), 'https://fest.example.com/page/about');
    // The document title is the app bar title.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('About')),
      findsOneWidget,
    );

    // Back to the index, then forward again.
    await tester.tap(find.byTooltip('Previous page'));
    await pumpUntil(tester, find.text('What is on'));
    expect(_address(tester), 'https://fest.example.com/');
    await tester.tap(find.byTooltip('Next page'));
    await pumpUntil(tester, _html('Hello'));

    // A navigation link of the site header.
    await tester.tap(find.widgetWithText(TextButton, 'Home'));
    await pumpUntil(tester, find.text('What is on'));
    expect(_address(tester), 'https://fest.example.com/');
  });

  testWidgets('follows the links of a body, never leaves the site', (
    tester,
  ) async {
    var sdb = await _openSite(tester);
    await _pumpBrowser(tester, sdb, initialPath: 'page/about');
    await pumpUntil(tester, _html('Hello'));

    // A root relative link, resolved against the page url.
    await tester.tapOnText(find.textRange.ofSubstring('the program'));
    await pumpUntil(tester, _html('What is on'));
    expect(_address(tester), 'https://fest.example.com/page/program');

    // An external link is shown, not followed.
    await tester.tap(find.byTooltip('Previous page'));
    await pumpUntil(tester, _html('Hello'));
    await tester.tapOnText(find.textRange.ofSubstring('elsewhere'));
    await tester.pump();
    expect(find.textContaining('Not on the site'), findsOneWidget);
    expect(_address(tester), 'https://fest.example.com/page/about');

    // The address bar takes a path as well as a url.
    await tester.enterText(find.byType(TextField), 'page/program');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpUntil(tester, _html('What is on'));
    expect(_address(tester), 'https://fest.example.com/page/program');
  });

  testWidgets('view modes, sitemap, not found and drafts', (tester) async {
    var sdb = await _openSite(tester);
    await _pumpBrowser(tester, sdb, initialPath: 'page/about');
    await pumpUntil(tester, _html('Hello'));

    // The html source.
    await tester.tap(find.text('Html'));
    await tester.pump();
    expect(find.textContaining('<!DOCTYPE html>'), findsOneWidget);

    // The SEO head.
    await tester.tap(find.text('SEO'));
    await tester.pump();
    // The description, as search engines and link previews read it.
    expect(find.text('Who we are'), findsNWidgets(3));
    expect(find.text('og:description'), findsOneWidget);
    expect(find.text('https://fest.example.com/page/about'), findsWidgets);
    expect(find.text('Indexed, followed'), findsOneWidget);
    // The structured data, at the bottom.
    await tester.scrollUntilVisible(
      find.textContaining('"@type": "WebPage"'),
      300,
      // The list itself, not the selectable texts it holds.
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    // The sitemap, from the menu.
    await tester.tap(find.text('Rendered'));
    await tester.tap(find.byTooltip('Go to'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('sitemap.xml'));
    await pumpUntil(tester, find.text('200 · application/xml'));
    expect(
      find.textContaining('page/program', findRichText: true),
      findsWidgets,
    );

    // A draft is not served...
    await tester.enterText(find.byType(TextField), '/page/hidden-draft');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpUntil(tester, find.text('404 · text/html'));
    expect(_html('Page not found'), findsWidgets);

    // ...unless the drafts are, and then it is not indexed.
    await tester.tap(find.widgetWithText(FilterChip, 'Drafts'));
    await pumpUntil(tester, find.text('Draft, not indexed'));
    expect(find.text('200 · text/html'), findsOneWidget);
    await tester.tap(find.text('SEO'));
    await tester.pump();
    expect(find.textContaining('Not indexed'), findsOneWidget);
  });

  testWidgets('renders again when a page changes', (tester) async {
    var sdb = await _openSite(tester);
    await _pumpBrowser(tester, sdb, initialPath: 'page/program');
    await pumpUntil(tester, _html('What is on'));

    await tester.runAsync(() async {
      var page = await sdb.getPageBySlug('program');
      await sdb.updatePage(page!.id, (page) => page.summary.v = 'Updated');
    });
    await pumpUntil(tester, _html('Updated'));
  });
}

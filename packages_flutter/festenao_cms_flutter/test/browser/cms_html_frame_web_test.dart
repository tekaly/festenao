/// The browser rendering, in a real browser:
///
/// ```sh
/// flutter test --platform chrome test/browser
/// ```
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:festenao_cms_flutter/src/html_frame/cms_html_iframe_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

/// A page whose own script tries to reach the app, then taps its links
/// (the test cannot: the frame is of another origin).
const _page =
    '<!DOCTYPE html><html><head>'
    '<base href="https://fest.example.com/page/a"></head><body>'
    '<p id="first"><a id="relative" href="b">b</a> '
    '<a id="root" href="/page/c"><span id="inner">c</span></a> '
    '<a id="anchor" href="#end">end</a></p>'
    '<p id="end">end</p>'
    '<script>'
    'try { window.parent.cmsFrameScriptRan = true; } catch (e) {}'
    'try { localStorage.setItem("cmsFrame", "1"); } catch (e) {}'
    'document.getElementById("relative").click();'
    'document.getElementById("inner").click();'
    'document.getElementById("anchor").click();'
    'document.getElementById("root").click();'
    '</script></body></html>';

/// An iframe set up on [html], in the page; its links go to [onLink].
web.HTMLIFrameElement _frame(String html, void Function(String href) onLink) {
  var iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
  var release = setUpCmsHtmlIFrame(iframe, html, () => onLink);
  web.document.body!.appendChild(iframe);
  addTearDown(() {
    release();
    iframe.remove();
  });
  return iframe;
}

/// Waits for [links] to hold [count] hrefs.
Future<void> _waitLinks(List<String> links, int count) async {
  for (var i = 0; i < 100 && links.length < count; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test(
    'a sandboxed iframe, of another origin, its links handed over',
    () async {
      expect(cmsHtmlFrameSupported, isTrue);
      var links = <String>[];
      var iframe = _frame(_page, links.add);
      expect(iframe.getAttribute('sandbox'), 'allow-scripts');

      // The raw href, whatever was tapped inside the link; an anchor scrolls,
      // it is not handed over.
      await _waitLinks(links, 3);
      expect(links, ['b', '/page/c', '/page/c']);

      // Of another origin: the app is out of reach of the page.
      expect(iframe.contentDocument, isNull);
      expect(globalContext.has('cmsFrameScriptRan'), isFalse);
      expect(web.window.localStorage.getItem('cmsFrame'), isNull);
    },
  );

  test('a message of another frame is ignored', () async {
    var links = <String>[];
    _frame('<p>quiet</p>', links.add);
    // Posted by the app window itself, not by the frame.
    web.window.postMessage('cms-frame-link:forged'.toJS, '*'.toJS);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(links, isEmpty);
  });

  test('a text document, its urls linked', () async {
    var links = <String>[];
    var html = cmsHtmlForBrowser(
      const CmsResponse.text('Sitemap: https://fest.example.com/sitemap.xml'),
      Uri.parse('https://fest.example.com/robots.txt'),
    );
    _frame(
      html.replaceFirst(
        '</body>',
        '<script>document.querySelector("a").click();</script></body>',
      ),
      links.add,
    );
    await _waitLinks(links, 1);
    expect(links, ['https://fest.example.com/sitemap.xml']);
  });

  testWidgets('the frame widget is a platform view', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CmsHtmlFrame(html: _page)),
      ),
    );
    expect(find.byType(HtmlElementView), findsOneWidget);
    // Another document is another platform view (a fresh iframe: no history
    // entry in the app).
    var first = tester.widget<HtmlElementView>(find.byType(HtmlElementView));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CmsHtmlFrame(html: '<p>other</p>')),
      ),
    );
    var second = tester.widget<HtmlElementView>(find.byType(HtmlElementView));
    expect(second.key, isNot(first.key));
  });
}

import 'dart:convert';

import 'package:festenao_common/festenao_cms.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// A meta tag of the head of a document (`name` or `property`, and `content`).
class CmsHtmlMeta {
  /// The `name` or `property` attribute.
  final String key;

  /// The `content` attribute.
  final String content;

  /// A meta tag.
  const CmsHtmlMeta({required this.key, required this.content});
}

/// What a generated html document says about itself: the head values a
/// search engine or a link preview reads, and the body the reader sees.
class CmsHtmlDocument {
  /// The source.
  final String source;

  /// `<html lang>`.
  final String? lang;

  /// `<title>`.
  final String? title;

  /// Meta description.
  final String? description;

  /// `<link rel="canonical">`.
  final String? canonicalUrl;

  /// Meta robots (`noindex, nofollow`), null when indexable.
  final String? robots;

  /// The open graph (`og:*`) and twitter (`twitter:*`) meta tags, in order.
  final List<CmsHtmlMeta> socialMetas;

  /// The other meta tags (generator...).
  final List<CmsHtmlMeta> otherMetas;

  /// The JSON-LD blocks, pretty printed (as is when not valid json).
  final List<String> jsonLd;

  /// The inner html of `<body>`.
  final String bodyHtml;

  CmsHtmlDocument._({
    required this.source,
    required this.lang,
    required this.title,
    required this.description,
    required this.canonicalUrl,
    required this.robots,
    required this.socialMetas,
    required this.otherMetas,
    required this.jsonLd,
    required this.bodyHtml,
  });

  /// True when a robots meta asks not to index the document.
  bool get isNoIndex => robots?.contains('noindex') ?? false;

  /// Parse an html document.
  factory CmsHtmlDocument.parse(String source) {
    var document = html_parser.parse(source);
    String? description;
    String? robots;
    var socialMetas = <CmsHtmlMeta>[];
    var otherMetas = <CmsHtmlMeta>[];
    for (var meta in document.querySelectorAll('meta')) {
      var key = meta.attributes['name'] ?? meta.attributes['property'];
      var content = meta.attributes['content'];
      if (key == null || content == null) {
        continue;
      }
      var entry = CmsHtmlMeta(key: key, content: content);
      if (key == 'description') {
        description = content;
      } else if (key == 'robots') {
        robots = content;
      } else if (key.startsWith('og:') || key.startsWith('twitter:')) {
        socialMetas.add(entry);
      } else {
        otherMetas.add(entry);
      }
    }
    var jsonLd = document
        .querySelectorAll('script[type="application/ld+json"]')
        .map((script) => _prettyJson(script.text))
        .toList();
    return CmsHtmlDocument._(
      source: source,
      lang: document.documentElement?.attributes['lang'],
      title: _text(document.querySelector('title')),
      description: description,
      canonicalUrl: document
          .querySelector('link[rel="canonical"]')
          ?.attributes['href'],
      robots: robots,
      socialMetas: socialMetas,
      otherMetas: otherMetas,
      jsonLd: jsonLd,
      bodyHtml: document.body?.innerHtml ?? source,
    );
  }

  static String? _text(dom.Element? element) {
    var text = element?.text.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  static String _prettyJson(String text) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
    } catch (_) {
      return text;
    }
  }
}

final _urlRegExp = RegExp(r'''https?://[^\s<>"']+''');

/// A plain text document (`robots.txt`, `sitemap.xml`) as html: preformatted,
/// its urls made links so that they can be followed.
String cmsPlainTextToLinkedHtml(String text) {
  var sb = StringBuffer('<pre>');
  var start = 0;
  for (var match in _urlRegExp.allMatches(text)) {
    sb.write(_escape(text.substring(start, match.start)));
    var url = _escape(match.group(0)!);
    sb.write('<a href="$url">$url</a>');
    start = match.end;
  }
  sb.write(_escape(text.substring(start)));
  sb.write('</pre>');
  return sb.toString();
}

/// `&`, `<`, `>` and `"` escaped, urls left readable (no `&#47;`).
String _escape(String text) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert(text);

final _headRegExp = RegExp(r'<head(\s[^>]*)?>', caseSensitive: false);

/// A response as the browser itself shows it (the web view): an html document
/// gets a `<base>` so that its relative urls resolve on the site rather than
/// on the app, a text document (`robots.txt`, `sitemap.xml`) is shown
/// preformatted, its urls made links.
String cmsHtmlForBrowser(CmsResponse response, Uri url) {
  var base = '<base href="${_escape(url.toString())}">';
  if (response.isHtml) {
    var html = response.body;
    var head = _headRegExp.firstMatch(html);
    if (head == null) {
      return '$base$html';
    }
    return html.replaceRange(head.end, head.end, base);
  }
  return '<!DOCTYPE html>\n<html>\n<head>\n<meta charset="utf-8">\n$base\n'
      '<title>${_escape(url.pathSegments.lastOrNull ?? url.toString())}</title>\n'
      '<style>body{margin:1rem;font-family:monospace;white-space:pre-wrap}'
      'pre{margin:0;white-space:pre-wrap;word-break:break-all}</style>\n'
      '</head>\n<body>${cmsPlainTextToLinkedHtml(response.body)}</body>\n'
      '</html>\n';
}

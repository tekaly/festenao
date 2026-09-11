import 'package:festenao_common/cms/cms_markdown.dart';
import 'package:festenao_common/cms/cms_page.dart';
import 'package:festenao_common/cms/cms_structured_data.dart';
import 'package:festenao_common/cms/cms_templates.dart';
import 'package:festenao_common/festenao_sdb.dart';
import 'package:tekartik_mustache/mustache.dart' as mustache;

/// Resolve the url of a page image, null when it cannot be shown.
typedef CmsImageUrlResolver = String? Function(CvCmsImage image);

/// A navigation link of the site header.
class CmsNavLink {
  /// Link text.
  final String label;

  /// Link target.
  final String url;

  /// A navigation link.
  const CmsNavLink({required this.label, required this.url});
}

/// A label/value shown in the details block of a page (an event date, a
/// price, an address...), supplied by the app for the item kinds it knows.
class CmsPageDetail {
  /// Label.
  final String label;

  /// Value (plain text).
  final String value;

  /// A page detail.
  const CmsPageDetail({required this.label, required this.value});
}

/// The site the pages belong to: what every page needs to know to build its
/// urls and its chrome.
class CmsSite {
  /// Site name (header, `og:site_name`).
  final String name;

  /// Absolute base url of the site, page urls are built under it.
  ///
  /// For a calendar served by a cloud function this is the function url plus
  /// the calendar path (`https://.../pagedev/calendelio-dev/<calendarId>`).
  final Uri baseUrl;

  /// Language code (`fr`, `en`), the `<html lang>` of pages without one.
  final String language;

  /// Site description, the default meta description of the index.
  final String? description;

  /// Header links.
  final List<CmsNavLink> nav;

  /// Logo url shown next to the site name.
  final String? logoUrl;

  /// Footer html, defaults to a copyright line.
  final String? footerHtml;

  /// Path of a page under [baseUrl], `page/` by default (`/page/<slug>`).
  final String pagePathPrefix;

  /// Generator meta tag, informative.
  final String? generator;

  /// A site.
  const CmsSite({
    required this.name,
    required this.baseUrl,
    this.language = 'fr',
    this.description,
    this.nav = const [],
    this.logoUrl,
    this.footerHtml,
    this.pagePathPrefix = 'page/',
    this.generator = 'festenao',
  });

  /// [baseUrl] as a string without trailing slash.
  String get baseUrlText {
    var text = baseUrl.toString();
    while (text.endsWith('/')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  /// An absolute url under the site.
  String url(String path) {
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    return path.isEmpty ? '$baseUrlText/' : '$baseUrlText/$path';
  }

  /// The absolute url of the page of [slug].
  String pageUrl(String slug) => url('$pagePathPrefix$slug');
}

/// What [CmsRenderer.renderPage] needs besides the page itself: the
/// structured data and details an app derives from the presented item.
class CmsPageRenderOptions {
  /// Schema.org map (see [CmsStructuredData]), defaults to a web page.
  final Map<String, Object?>? structuredData;

  /// Details block (date, price, address...).
  final List<CmsPageDetail> details;

  /// Open graph type, defaults to `article`.
  final String? ogType;

  /// Extra values handed to the page template.
  final Map<String, Object?> extra;

  /// Render options.
  const CmsPageRenderOptions({
    this.structuredData,
    this.details = const [],
    this.ogType,
    this.extra = const {},
  });
}

/// Renders CMS pages to static html with mustache templates.
///
/// Pure Dart, no io: usable from a cloud function, a build tool, or a test.
/// Escaping is mustache's: `{{value}}` is html escaped, only the values the
/// renderer produces itself (the rendered body, the json-ld, the css) are
/// injected raw.
class CmsRenderer {
  /// The site.
  final CmsSite site;

  /// The templates.
  final CmsTemplates templates;

  /// Image url resolver, defaults to the image url field.
  final CmsImageUrlResolver? imageUrlResolver;

  /// A renderer for [site].
  CmsRenderer({
    required this.site,
    this.templates = CmsTemplates.defaults,
    this.imageUrlResolver,
  });

  /// The absolute url of a page.
  String pageUrl(SdbCmsPage page) =>
      site.pageUrl(page.slug.v ?? page.idOrNull ?? '');

  String? _imageUrl(CvCmsImage? image) {
    if (image == null) {
      return null;
    }
    var resolver = imageUrlResolver;
    if (resolver != null) {
      return resolver(image);
    }
    return image.url.v;
  }

  Map<String, Object?>? _imageValues(CvCmsImage? image) {
    var url = _imageUrl(image);
    if (image == null || url == null) {
      return null;
    }
    return {
      'url': _attr(url),
      'alt': image.alt.v ?? '',
      'caption': image.caption.v,
      'width': image.width.v,
      'height': image.height.v,
    };
  }

  static String? _isoDate(Object? timestamp) {
    String text;
    if (timestamp == null) {
      return null;
    } else if (timestamp is SdbTimestamp) {
      text = timestamp.toIso8601String();
    } else if (timestamp is DateTime) {
      text = timestamp.toUtc().toIso8601String();
    } else {
      text = timestamp.toString();
    }
    return text.split('T').first;
  }

  /// Mustache sections cannot test an empty string, make it null.
  static Object? _normalize(Object? value) {
    if (value is String) {
      return value.isEmpty ? null : value;
    } else if (value is Map) {
      return value.map((key, value) => MapEntry(key, _normalize(value)));
    } else if (value is List) {
      return value.map(_normalize).toList();
    }
    return value;
  }

  /// The html of the body of a page.
  String bodyHtml(SdbCmsPage page) {
    var body = page.body.v ?? '';
    return page.isMarkdown ? cmsMarkdownToHtml(body) : body;
  }

  /// The meta description of a page.
  String description(SdbCmsPage page) {
    var text = page.seoDescription.v ?? page.summary.v;
    if (text != null && text.isNotEmpty) {
      return text;
    }
    var body = page.body.v ?? '';
    return page.isMarkdown
        ? cmsMarkdownExcerpt(body)
        : cmsMarkdownExcerpt(body);
  }

  /// The image urls of a page, hero first (structured data, open graph).
  List<String> imageUrls(SdbCmsPage page) =>
      page.allImages.map(_imageUrl).nonNulls.toList();

  /// The default structured data of a page: a web page.
  Map<String, Object?> defaultStructuredData(SdbCmsPage page) =>
      CmsStructuredData.webPage(
        name: page.title.v ?? page.displayTitle,
        description: description(page),
        url: page.canonicalUrl.v ?? pageUrl(page),
        datePublished: _isoDate(page.publishedAt.v),
        dateModified: _isoDate(page.updated.v),
        images: imageUrls(page),
      );

  Map<String, Object?> _layoutValues({
    required String title,
    required String? description,
    required String? canonicalUrl,
    required String content,
    String? imageUrl,
    Map<String, Object?>? structuredData,
    String ogType = 'website',
    String? lang,
    bool noIndex = false,
  }) => {
    'lang': lang ?? site.language,
    'title': title,
    'description': description,
    'canonicalUrl': _attr(canonicalUrl),
    'noIndex': noIndex,
    'ogType': ogType,
    'siteName': site.name,
    'siteUrl': _attr(site.url('')),
    'logoUrl': _attr(site.logoUrl),
    'imageUrl': _attr(imageUrl),
    'jsonLd': structuredData == null
        ? null
        : CmsStructuredData.toJsonLd(structuredData),
    'generator': site.generator,
    'css': templates.css,
    'hasNav': site.nav.isNotEmpty,
    'nav': site.nav
        .map((link) => {'label': link.label, 'url': _attr(link.url)})
        .toList(),
    'footerHtml': site.footerHtml,
    'year': DateTime.now().year.toString(),
    'content': content,
  };

  Future<String> _render(String template, Map<String, Object?> values) async =>
      (await mustache.render(
        template,
        (_normalize(values) as Map).cast<String, Object?>(),
      ))!;

  /// The values the page template receives.
  Map<String, Object?> pageValues(
    SdbCmsPage page, {
    CmsPageRenderOptions options = const CmsPageRenderOptions(),
  }) {
    var images = (page.images.v ?? const <CvCmsImage>[])
        .map(_imageValues)
        .nonNulls
        .toList();
    var tags = page.tags.v ?? const <String>[];
    return {
      'id': page.idOrNull,
      'slug': page.slug.v,
      'title': page.title.v ?? page.displayTitle,
      'summary': page.summary.v,
      'heroImage': _imageValues(page.heroImage.v),
      'bodyHtml': bodyHtml(page),
      'hasImages': images.isNotEmpty,
      'images': images,
      'hasTags': tags.isNotEmpty,
      'tags': tags.map((tag) => {'tag': tag}).toList(),
      'hasDetails': options.details.isNotEmpty,
      'details': options.details
          .map((detail) => {'label': detail.label, 'value': detail.value})
          .toList(),
      'itemKind': page.kind,
      'itemId': page.itemId.v,
      'publishedAt': _isoDate(page.publishedAt.v),
      'updatedAt': _isoDate(page.updated.v),
      'url': _attr(pageUrl(page)),
      'data': page.data.v,
      ...options.extra,
    };
  }

  /// Render a page to a complete html document.
  Future<String> renderPage(
    SdbCmsPage page, {
    CmsPageRenderOptions options = const CmsPageRenderOptions(),
  }) async {
    var content = await _render(
      templates.page,
      pageValues(page, options: options),
    );
    return await _render(
      templates.layout,
      _layoutValues(
        title: page.displayTitle,
        description: description(page),
        canonicalUrl: page.canonicalUrl.v ?? pageUrl(page),
        content: content,
        imageUrl: _imageUrl(page.heroImage.v) ?? imageUrls(page).firstOrNull,
        structuredData: options.structuredData ?? defaultStructuredData(page),
        ogType: options.ogType ?? 'article',
        lang: page.lang.v,
        noIndex: page.noIndex.v ?? false,
      ),
    );
  }

  /// Render the list of [pages] (only the published ones are expected).
  Future<String> renderIndex(
    List<SdbCmsPage> pages, {
    String? title,
    String? description,
    String? path = '',
    String emptyMessage = 'Nothing published yet.',
  }) async {
    title ??= site.name;
    description ??= site.description;
    var content = await _render(templates.index, {
      'title': title,
      'description': description,
      'hasPages': pages.isNotEmpty,
      'emptyMessage': emptyMessage,
      'pages': pages
          .map(
            (page) => {
              'title': page.title.v ?? page.displayTitle,
              'summary': page.summary.v,
              'url': _attr(pageUrl(page)),
              'imageUrl': _attr(_imageUrl(page.heroImage.v)),
              'itemKind': page.kind,
            },
          )
          .toList(),
    });
    return await _render(
      templates.layout,
      _layoutValues(
        title: title,
        description: description,
        canonicalUrl: path == null ? null : site.url(path),
        content: content,
        imageUrl: pages
            .map((page) => _imageUrl(page.heroImage.v))
            .nonNulls
            .firstOrNull,
        structuredData: CmsStructuredData.webPage(
          name: title,
          description: description,
          url: path == null ? null : site.url(path),
        ),
      ),
    );
  }

  /// Render a not found document (serve it with a 404 status).
  Future<String> renderNotFound({
    String title = 'Page not found',
    String message = 'This page does not exist or is no longer published.',
  }) async {
    var content = await _render(templates.notFound, {
      'title': title,
      'message': message,
      'siteName': site.name,
      'siteUrl': _attr(site.url('')),
    });
    return await _render(
      templates.layout,
      _layoutValues(
        title: title,
        description: null,
        canonicalUrl: null,
        content: content,
        noIndex: true,
      ),
    );
  }

  /// The `sitemap.xml` of the published [pages].
  String renderSitemap(List<SdbCmsPage> pages, {bool includeIndex = true}) {
    var sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
    void url(String loc, String? lastmod) {
      sb.write('<url><loc>${_xmlEscape(loc)}</loc>');
      if (lastmod != null) {
        sb.write('<lastmod>$lastmod</lastmod>');
      }
      sb.writeln('</url>');
    }

    if (includeIndex) {
      url(site.url(''), null);
    }
    for (var page in pages) {
      if (!page.isPublished || page.noIndex.v == true) {
        continue;
      }
      url(pageUrl(page), _isoDate(page.updated.v ?? page.publishedAt.v));
    }
    sb.writeln('</urlset>');
    return sb.toString();
  }

  /// The `robots.txt` of the site.
  String renderRobots({bool allow = true}) {
    var sb = StringBuffer();
    sb.writeln('User-agent: *');
    sb.writeln(allow ? 'Allow: /' : 'Disallow: /');
    sb.writeln('Sitemap: ${site.url('sitemap.xml')}');
    return sb.toString();
  }

  /// Escape a value injected raw in an html attribute (urls, so `/` stays).
  static String? _attr(String? text) => text == null ? null : _xmlEscape(text);

  static String _xmlEscape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

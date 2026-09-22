import 'dart:async';

import 'package:festenao_common/cms/cms_page.dart';
import 'package:festenao_common/cms/cms_renderer.dart';
import 'package:festenao_common/festenao_sdb.dart';

/// Content type of an html document.
const cmsContentTypeHtml = 'text/html; charset=utf-8';

/// Content type of a plain text document (`robots.txt`).
const cmsContentTypeText = 'text/plain; charset=utf-8';

/// Content type of an xml document (`sitemap.xml`).
const cmsContentTypeXml = 'application/xml; charset=utf-8';

/// What a [CmsSiteHandler] answers: what an http server sends back.
class CmsResponse {
  /// Http status.
  final int statusCode;

  /// Content type header.
  final String contentType;

  /// Body.
  final String body;

  /// A response.
  const CmsResponse(this.statusCode, this.contentType, this.body);

  /// An html response.
  const CmsResponse.html(this.body, {this.statusCode = 200})
    : contentType = cmsContentTypeHtml;

  /// A plain text response.
  const CmsResponse.text(this.body, {this.statusCode = 200})
    : contentType = cmsContentTypeText;

  /// An xml response.
  const CmsResponse.xml(this.body, {this.statusCode = 200})
    : contentType = cmsContentTypeXml;

  /// True for an html document.
  bool get isHtml => contentType.startsWith('text/html');

  /// True for a 2xx status.
  bool get isOk => statusCode >= 200 && statusCode < 300;

  @override
  String toString() => 'CmsResponse($statusCode, $contentType)';
}

/// The render options of a page, derived by the app from the item it presents
/// (an event date, a location address...).
typedef CmsPageRenderOptionsBuilder =
    FutureOr<CmsPageRenderOptions> Function(SdbCmsPage page);

/// Serves the pages of a [CmsPageSdb] as a static site.
///
/// Urls, under the site base url:
///
/// ```
/// <base>/                    index (the published pages)
/// <base>/page/<slug>         a page (see CmsSite.pagePathPrefix)
/// <base>/sitemap.xml
/// <base>/robots.txt
/// ```
///
/// Anything else is a 404, and so is an unpublished page unless
/// [includeDrafts] is set: the handler answers what a cloud function serves,
/// and what an app shows when previewing the site.
class CmsSiteHandler {
  /// The pages.
  final CmsPageSdb pages;

  /// The renderer, holding the site.
  final CmsRenderer renderer;

  /// True to serve the unpublished pages too, at their url (an admin preview).
  ///
  /// They stay out of the index and the sitemap, and are rendered no index:
  /// the preview shows the site as it is served, drafts reachable by url.
  final bool includeDrafts;

  /// The render options of a page, none by default.
  final CmsPageRenderOptionsBuilder? pageOptions;

  /// A handler serving [pages] with [renderer].
  CmsSiteHandler({
    required this.pages,
    required this.renderer,
    this.includeDrafts = false,
    this.pageOptions,
  });

  /// The site.
  CmsSite get site => renderer.site;

  /// The path of [url] below the site base url (no leading slash, `''` for
  /// the index), null when [url] is not on the site.
  ///
  /// A relative url is read as a path below the base url.
  String? pathOf(Uri url) {
    if (!url.hasScheme && !url.hasAuthority) {
      return _normalizePath(url.path);
    }
    var base = site.baseUrl;
    if (url.scheme != base.scheme ||
        url.host != base.host ||
        url.port != base.port) {
      return null;
    }
    var basePath = site.baseUrl.path;
    if (!basePath.endsWith('/')) {
      basePath = '$basePath/';
    }
    var path = url.path;
    if (path == basePath.substring(0, basePath.length - 1)) {
      return '';
    }
    if (!path.startsWith(basePath)) {
      return null;
    }
    return _normalizePath(path.substring(basePath.length));
  }

  static String _normalizePath(String path) {
    var segments = path.split('/').where((segment) => segment.isNotEmpty);
    return segments.map(Uri.decodeComponent).join('/');
  }

  /// The absolute url of a path of the site.
  String urlOf(String path) => site.url(path);

  /// Handle a request for [url], a 404 when not on the site.
  Future<CmsResponse> handleUrl(Uri url) async {
    var path = pathOf(url);
    if (path == null) {
      return await notFound();
    }
    return await handlePath(path);
  }

  /// Handle a request for [path], below the site base url.
  Future<CmsResponse> handlePath(String path) async {
    path = _normalizePath(path);
    switch (path) {
      case '':
      case 'index.html':
        return CmsResponse.html(
          await renderer.renderIndex(await pages.getPages(publishedOnly: true)),
        );
      case 'sitemap.xml':
        return CmsResponse.xml(
          renderer.renderSitemap(await pages.getPages(publishedOnly: true)),
        );
      case 'robots.txt':
        return CmsResponse.text(renderer.renderRobots());
    }
    var prefix = site.pagePathPrefix;
    if (path.startsWith(prefix)) {
      var slug = path.substring(prefix.length);
      if (slug.isNotEmpty) {
        var page = await pages.getPageBySlug(slug);
        if (page != null && (page.isPublished || includeDrafts)) {
          return CmsResponse.html(await renderPage(page));
        }
      }
    }
    return await notFound();
  }

  /// Render one page, whatever its published state.
  Future<String> renderPage(SdbCmsPage page) async {
    if (!page.isPublished) {
      // A draft shown in a preview is never to be indexed.
      page = SdbCmsPage()
        ..copyFrom(page)
        ..noIndex.v = true;
    }
    var options = await pageOptions?.call(page);
    return await renderer.renderPage(
      page,
      options: options ?? const CmsPageRenderOptions(),
    );
  }

  /// The not found response.
  Future<CmsResponse> notFound() async =>
      CmsResponse.html(await renderer.renderNotFound(), statusCode: 404);
}

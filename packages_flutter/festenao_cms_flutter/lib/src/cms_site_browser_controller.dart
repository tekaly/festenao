import 'dart:async';

import 'package:festenao_cms_flutter/src/widget/cms_html_document.dart';
import 'package:festenao_common/festenao_cms.dart';
import 'package:flutter/foundation.dart';

/// A browsing session on the site the pages render to: the history of the
/// paths visited, and the document at the current one, rendered on the fly
/// through a [CmsSiteHandler] (what the cloud function serves).
///
/// Shared by the site browser screens — `CmsSiteBrowserScreen` (drawn by
/// Flutter) and `CmsSiteWebViewScreen` (drawn by the browser itself, on the
/// web) — so that both show the same page and the same history. A change to
/// the pages renders the current document again.
class CmsSiteBrowserController extends ChangeNotifier {
  /// The pages.
  final CmsPageSdb pages;

  /// The renderer, holding the site.
  final CmsRenderer renderer;

  /// The render options of a page (details, structured data).
  final CmsPageRenderOptionsBuilder? pageOptions;

  final _history = <String>[];
  var _historyIndex = 0;
  bool _includeDrafts;
  CmsResponse? _response;
  CmsHtmlDocument? _document;
  SdbCmsPage? _page;
  Object? _error;
  var _loading = false;
  var _generation = 0;
  var _disposed = false;
  StreamSubscription<void>? _pagesSubscription;

  /// A session on [pages], opened at [initialPath] (`''` for the index).
  CmsSiteBrowserController({
    required this.pages,
    required this.renderer,
    this.pageOptions,
    this._includeDrafts = false,
    String initialPath = '',
  }) {
    _history.add(initialPath);
    // The first event is the pages as they are now.
    _pagesSubscription = pages.onPages().skip(1).listen((_) => reload());
    reload();
  }

  /// The site.
  CmsSite get site => renderer.site;

  /// The handler rendering the site, drafts included when [includeDrafts].
  CmsSiteHandler get handler => CmsSiteHandler(
    pages: pages,
    renderer: renderer,
    includeDrafts: _includeDrafts,
    pageOptions: pageOptions,
  );

  /// The current path, below the site base url.
  String get path => _history[_historyIndex];

  /// The absolute url of [path].
  Uri urlOf(String path) => Uri.parse(site.url(path));

  /// The current url.
  Uri get url => urlOf(path);

  /// The path of [url] on the site, null when it is elsewhere.
  String? pathOfUrl(Uri url) => handler.pathOf(url);

  /// The response at [path], null until rendered.
  CmsResponse? get response => _response;

  /// The html document at [path], null when not html (sitemap, robots).
  CmsHtmlDocument? get document => _document;

  /// The page at [path], null when it is not a page.
  SdbCmsPage? get page => _page;

  /// The rendering error, if any.
  Object? get error => _error;

  /// True while rendering.
  bool get isLoading => _loading;

  /// Whether the unpublished pages are served at their url.
  bool get includeDrafts => _includeDrafts;

  set includeDrafts(bool value) {
    if (value != _includeDrafts) {
      _includeDrafts = value;
      reload();
    }
  }

  /// True when there is a page to go back to.
  bool get canGoBack => _historyIndex > 0;

  /// True when there is a page to go forward to.
  bool get canGoForward => _historyIndex < _history.length - 1;

  /// Opens [path], forgetting what was forward of the current one.
  void go(String path) {
    if (path != this.path) {
      _history
        ..removeRange(_historyIndex + 1, _history.length)
        ..add(path);
      _historyIndex = _history.length - 1;
    }
    reload();
  }

  /// The previous page.
  void back() {
    if (canGoBack) {
      _historyIndex--;
      reload();
    }
  }

  /// The next page.
  void forward() {
    if (canGoForward) {
      _historyIndex++;
      reload();
    }
  }

  /// Renders [path], without opening it (another tab, a crawler).
  Future<CmsResponse> fetch(String path) => handler.handlePath(path);

  /// Renders the current path again.
  Future<void> reload() async {
    var generation = ++_generation;
    var handler = this.handler;
    var path = this.path;
    _loading = true;
    _notify();
    try {
      var response = await handler.handlePath(path);
      SdbCmsPage? page;
      var prefix = site.pagePathPrefix;
      if (response.isOk &&
          response.isHtml &&
          path.startsWith(prefix) &&
          path.length > prefix.length) {
        page = await pages.getPageBySlug(path.substring(prefix.length));
      }
      if (generation != _generation) {
        return;
      }
      _response = response;
      _document = response.isHtml ? CmsHtmlDocument.parse(response.body) : null;
      _page = page;
      _error = null;
    } catch (e) {
      if (generation != _generation) {
        return;
      }
      _error = e;
    }
    _loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pagesSubscription?.cancel();
    super.dispose();
  }
}

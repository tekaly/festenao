import 'package:festenao_cms_flutter/src/cms_site_browser_controller.dart';
import 'package:festenao_cms_flutter/src/html_frame/cms_html_frame.dart';
import 'package:festenao_cms_flutter/src/provider/cms_page_providers.dart';
import 'package:festenao_cms_flutter/src/screen/cms_site_web_view_screen.dart';
import 'package:festenao_cms_flutter/src/widget/cms_html_document.dart';
import 'package:festenao_cms_flutter/src/widget/cms_rendered_html_view.dart';
import 'package:festenao_cms_flutter/src/widget/cms_site_browser_bars.dart';
import 'package:festenao_common/festenao_cms.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How [CmsSiteBrowserScreen] shows a document.
enum CmsSiteViewMode {
  /// The html rendered as widgets, links followed within the site.
  rendered('Rendered', Icons.web_outlined),

  /// The html source, as served.
  source('Html', Icons.code),

  /// What the head tells search engines and link previews.
  seo('SEO', Icons.travel_explore);

  /// Segment label.
  final String label;

  /// Segment icon.
  final IconData icon;

  const CmsSiteViewMode(this.label, this.icon);
}

/// Browse the site the pages render to: the html a cloud function serves
/// (index, pages, sitemap, robots, not found), generated on the fly from the
/// database and navigated like a web site.
///
/// Reads the pages from [cmsPageSdbProvider] and renders them through a
/// [CmsSiteHandler] on [renderer], so what shows is what is served; a change
/// to the pages re-renders the current document. [CmsSiteViewMode] picks
/// between the rendered page (drawn by Flutter), its html source and its SEO
/// head.
///
/// On the web, the page can also be looked at as the browser itself draws
/// it, css included: in a [CmsSiteWebViewScreen] sharing the history of this
/// one, or in a new browser tab ([cmsSiteOpenInNewTab]).
class CmsSiteBrowserScreen extends ConsumerStatefulWidget {
  /// The renderer, holding the site (name, base url, navigation).
  final CmsRenderer renderer;

  /// The path the browser opens on, below the site base url (`''` for the
  /// index, `page/<slug>` for a page).
  final String initialPath;

  /// Serve the drafts at their url too (the toggle starts there).
  final bool includeDrafts;

  /// The render options of a page (details, structured data).
  final CmsPageRenderOptionsBuilder? pageOptions;

  /// The view mode it starts in.
  final CmsSiteViewMode initialViewMode;

  /// The font of the html source and the JSON-LD, `monospace` by default.
  final String? monospaceFontFamily;

  /// Called to edit the page on screen (an edit button shows when set).
  final void Function(BuildContext context, SdbCmsPage page)? onEditPage;

  /// A site browser.
  const CmsSiteBrowserScreen({
    super.key,
    required this.renderer,
    this.initialPath = '',
    this.includeDrafts = false,
    this.pageOptions,
    this.initialViewMode = CmsSiteViewMode.rendered,
    this.monospaceFontFamily,
    this.onEditPage,
  });

  /// The path of [page] on the site of [renderer].
  static String pagePath(CmsRenderer renderer, SdbCmsPage page) =>
      '${renderer.site.pagePathPrefix}${page.slug.v ?? page.id}';

  @override
  ConsumerState<CmsSiteBrowserScreen> createState() =>
      _CmsSiteBrowserScreenState();
}

class _CmsSiteBrowserScreenState extends ConsumerState<CmsSiteBrowserScreen> {
  late final _controller = CmsSiteBrowserController(
    pages: ref.read(cmsPageSdbProvider),
    renderer: widget.renderer,
    pageOptions: widget.pageOptions,
    includeDrafts: widget.includeDrafts,
    initialPath: widget.initialPath,
  );
  late var _viewMode = widget.initialViewMode;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showNotOnSite(Uri url) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Not on the site: $url')));
  }

  /// Follows a link: within the site it is opened here, elsewhere it is only
  /// shown (the preview never leaves the site).
  void _follow(String href) {
    var url = _controller.url.resolve(href);
    var path = _controller.pathOfUrl(url);
    if (path == null) {
      _showNotOnSite(url);
      return;
    }
    _controller.go(path);
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$what copied')));
    }
  }

  /// The browser rendering, in a screen sharing this history (web only).
  void _openWebView() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CmsSiteWebViewScreen(
          controller: _controller,
          monospaceFontFamily: widget.monospaceFontFamily,
          onEditPage: widget.onEditPage,
        ),
      ),
    );
  }

  void _openInNewTab() {
    if (!cmsSiteOpenInNewTab(_controller)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('The browser blocked the new tab')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    var controller = _controller;
    var page = controller.page;
    var onEditPage = widget.onEditPage;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          controller.document?.title ?? controller.site.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (page != null && onEditPage != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit this page',
              onPressed: () => onEditPage(context, page),
            ),
          if (cmsHtmlFrameSupported)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: 'Browser rendering',
              onPressed: _openWebView,
            ),
          PopupMenuButton<String>(
            tooltip: 'Go to',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'copyUrl':
                  _copy(controller.url.toString(), 'Url');
                case 'copySource':
                  _copy(controller.response?.body ?? '', 'Source');
                case 'newTab':
                  _openInNewTab();
                default:
                  controller.go(value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: '',
                child: ListTile(
                  leading: Icon(Icons.home_outlined),
                  title: Text('Index'),
                ),
              ),
              const PopupMenuItem(
                value: 'sitemap.xml',
                child: ListTile(
                  leading: Icon(Icons.account_tree_outlined),
                  title: Text('sitemap.xml'),
                ),
              ),
              const PopupMenuItem(
                value: 'robots.txt',
                child: ListTile(
                  leading: Icon(Icons.smart_toy_outlined),
                  title: Text('robots.txt'),
                ),
              ),
              const PopupMenuDivider(),
              if (cmsHtmlFrameSupported)
                const PopupMenuItem(
                  value: 'newTab',
                  child: ListTile(
                    leading: Icon(Icons.open_in_new),
                    title: Text('Open in a new tab'),
                  ),
                ),
              const PopupMenuItem(
                value: 'copyUrl',
                child: ListTile(
                  leading: Icon(Icons.link),
                  title: Text('Copy the url'),
                ),
              ),
              const PopupMenuItem(
                value: 'copySource',
                child: ListTile(
                  leading: Icon(Icons.content_copy),
                  title: Text('Copy the source'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CmsSiteAddressBar(
            controller: controller,
            monospaceFontFamily: widget.monospaceFontFamily,
            onNotOnSite: _showNotOnSite,
          ),
          CmsSiteStatusBar(
            controller: controller,
            leading: [
              SegmentedButton<CmsSiteViewMode>(
                showSelectedIcon: false,
                segments: [
                  for (var mode in CmsSiteViewMode.values)
                    ButtonSegment(
                      value: mode,
                      label: Text(mode.label),
                      icon: Icon(mode.icon),
                    ),
                ],
                selected: {_viewMode},
                onSelectionChanged: (selection) =>
                    setState(() => _viewMode = selection.single),
              ),
            ],
          ),
          if (controller.isLoading)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
          const Divider(height: 1),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    var error = _controller.error;
    if (error != null) {
      return Center(child: Text('Error: $error'));
    }
    var response = _controller.response;
    if (response == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return switch (_viewMode) {
      CmsSiteViewMode.rendered => _buildRendered(context, response),
      CmsSiteViewMode.source => _buildSource(context, response),
      CmsSiteViewMode.seo => _buildSeo(context, response),
    };
  }

  Widget _centered(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      // The --max of the default css.
      constraints: const BoxConstraints(maxWidth: 900),
      child: child,
    ),
  );

  Widget _buildRendered(BuildContext context, CmsResponse response) {
    var document = _controller.document;
    return SingleChildScrollView(
      key: PageStorageKey('rendered:${_controller.path}'),
      padding: const EdgeInsets.all(16),
      child: _centered(
        CmsRenderedHtmlView(
          bodyHtml:
              document?.bodyHtml ?? cmsPlainTextToLinkedHtml(response.body),
          baseUrl: _controller.url,
          onLink: _follow,
          monospaceFontFamily: widget.monospaceFontFamily,
        ),
      ),
    );
  }

  Widget _buildSource(BuildContext context, CmsResponse response) {
    var theme = Theme.of(context);
    return SingleChildScrollView(
      key: PageStorageKey('source:${_controller.path}'),
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        response.body,
        style: cmsMonospaceStyle(
          theme.textTheme.bodySmall,
          widget.monospaceFontFamily,
        ),
      ),
    );
  }

  Widget _buildSeo(BuildContext context, CmsResponse response) {
    var theme = Theme.of(context);
    var document = _controller.document;
    if (document == null) {
      return Center(
        child: Text(
          'Not an html document: ${response.contentType.split(';').first}',
        ),
      );
    }

    Widget section(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    Widget value(String label, String? text, {int? maxLength}) {
      var length = text?.length ?? 0;
      var tooLong = maxLength != null && length > maxLength;
      return ListTile(
        dense: true,
        title: Text(label),
        subtitle: SelectableText(
          text ?? '(none)',
          style: text == null
              ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
              : null,
        ),
        trailing: maxLength == null || text == null
            ? null
            : Text(
                '$length / $maxLength',
                style: TextStyle(
                  color: tooLong
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
      );
    }

    return ListView(
      key: PageStorageKey('seo:${_controller.path}'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        section('Search engines'),
        value('Title', document.title, maxLength: 60),
        value('Description', document.description, maxLength: 160),
        value('Canonical url', document.canonicalUrl),
        value('Language', document.lang),
        ListTile(
          dense: true,
          title: const Text('Indexing'),
          subtitle: Text(
            document.isNoIndex
                ? 'Not indexed (${document.robots})'
                : 'Indexed, followed',
          ),
          leading: Icon(
            document.isNoIndex ? Icons.visibility_off : Icons.visibility,
          ),
        ),
        section('Link previews (open graph, twitter)'),
        for (var meta in document.socialMetas) value(meta.key, meta.content),
        if (document.otherMetas.isNotEmpty) ...[
          section('Other'),
          for (var meta in document.otherMetas) value(meta.key, meta.content),
        ],
        section('Structured data (JSON-LD)'),
        if (document.jsonLd.isEmpty) value('JSON-LD', null),
        for (var jsonLd in document.jsonLd)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                jsonLd,
                style: cmsMonospaceStyle(
                  theme.textTheme.bodySmall,
                  widget.monospaceFontFamily,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

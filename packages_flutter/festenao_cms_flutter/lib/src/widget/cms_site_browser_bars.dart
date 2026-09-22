import 'package:festenao_cms_flutter/src/cms_site_browser_controller.dart';
import 'package:festenao_common/festenao_cms.dart';
import 'package:flutter/material.dart';

/// [style] in [family], `monospace` by default.
TextStyle? cmsMonospaceStyle(TextStyle? style, String? family) =>
    style?.copyWith(
      fontFamily: family ?? 'monospace',
      fontFamilyFallback: const ['monospace'],
    );

/// The address bar of the site browsers: back, forward, home, the url (a url
/// or a path can be typed), render again.
class CmsSiteAddressBar extends StatefulWidget {
  /// The session.
  final CmsSiteBrowserController controller;

  /// The font of the url.
  final String? monospaceFontFamily;

  /// Called with a typed url that is not on the site.
  final ValueChanged<Uri>? onNotOnSite;

  /// An address bar on [controller].
  const CmsSiteAddressBar({
    super.key,
    required this.controller,
    this.monospaceFontFamily,
    this.onNotOnSite,
  });

  @override
  State<CmsSiteAddressBar> createState() => _CmsSiteAddressBarState();
}

class _CmsSiteAddressBarState extends State<CmsSiteAddressBar> {
  final _textController = TextEditingController();
  Uri? _shownUrl;

  CmsSiteBrowserController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _syncUrl();
  }

  @override
  void didUpdateWidget(covariant CmsSiteAddressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      _controller.addListener(_onChange);
      _syncUrl();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _textController.dispose();
    super.dispose();
  }

  /// Shows the url once it changes, leaving what is being typed alone
  /// otherwise.
  void _syncUrl() {
    var url = _controller.url;
    if (url != _shownUrl) {
      _shownUrl = url;
      _textController.text = url.toString();
    }
  }

  void _onChange() {
    _syncUrl();
    if (mounted) {
      setState(() {});
    }
  }

  void _submit(String text) {
    text = text.trim();
    var url = Uri.tryParse(text);
    if (url == null) {
      return;
    }
    var path = _controller.pathOfUrl(url);
    if (path == null) {
      widget.onNotOnSite?.call(url);
      return;
    }
    // The same url again renders it again.
    _shownUrl = null;
    _controller.go(path);
  }

  @override
  Widget build(BuildContext context) {
    var controller = _controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Previous page',
            onPressed: controller.canGoBack ? controller.back : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            tooltip: 'Next page',
            onPressed: controller.canGoForward ? controller.forward : null,
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Site index',
            onPressed: () => controller.go(''),
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  controller.response?.isOk == false
                      ? Icons.error_outline
                      : Icons.public,
                  size: 18,
                ),
              ),
              keyboardType: TextInputType.url,
              style: cmsMonospaceStyle(
                Theme.of(context).textTheme.bodyMedium,
                widget.monospaceFontFamily,
              ),
              onSubmitted: _submit,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Render again',
            onPressed: controller.reload,
          ),
        ],
      ),
    );
  }
}

/// The line under the address bar: [leading] (a view mode picker), the
/// drafts toggle, the status of the response, a draft marker.
class CmsSiteStatusBar extends StatelessWidget {
  /// The session.
  final CmsSiteBrowserController controller;

  /// Shown first.
  final List<Widget> leading;

  /// A status bar on [controller].
  const CmsSiteStatusBar({
    super.key,
    required this.controller,
    this.leading = const [],
  });

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var response = controller.response;
    var page = controller.page;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...leading,
          FilterChip(
            label: const Text('Drafts'),
            tooltip: 'Serve the unpublished pages at their url',
            selected: controller.includeDrafts,
            onSelected: (value) => controller.includeDrafts = value,
          ),
          if (response != null)
            Chip(
              avatar: Icon(
                response.isOk
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                size: 18,
                color: response.isOk
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              label: Text(
                '${response.statusCode} · '
                '${response.contentType.split(';').first}',
              ),
            ),
          if (page != null && !page.isPublished)
            const Chip(
              avatar: Icon(Icons.visibility_off, size: 18),
              label: Text('Draft, not indexed'),
            ),
        ],
      ),
    );
  }
}

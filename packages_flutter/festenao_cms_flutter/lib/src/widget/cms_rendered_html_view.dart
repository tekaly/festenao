import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;

/// Called when a link of a rendered document is tapped, with its href as
/// written (resolve it against the document url).
typedef CmsHtmlLinkCallback = void Function(String href);

/// The body of a generated html document, rendered as widgets.
///
/// Flutter does not run css, so the classes of the default templates
/// (`site-header`, `cards`, `details`, `tag`, `site-footer`...) are drawn
/// with the app theme instead: the page reads like the site, in the colours
/// of the app. A custom template renders as plain html.
class CmsRenderedHtmlView extends StatelessWidget {
  /// The inner html of `<body>`.
  final String bodyHtml;

  /// The url the document was served at, to resolve images.
  final Uri? baseUrl;

  /// Called when a link is tapped.
  final CmsHtmlLinkCallback? onLink;

  /// The font of `<pre>` and `<code>`, the widget's own (`Courier`) by
  /// default.
  final String? monospaceFontFamily;

  /// A rendered document.
  const CmsRenderedHtmlView({
    super.key,
    required this.bodyHtml,
    this.baseUrl,
    this.onLink,
    this.monospaceFontFamily,
  });

  static String _css(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  void _tap(String? href) {
    if (href != null && href.isNotEmpty) {
      onLink?.call(href);
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var colors = theme.colorScheme;
    var muted = _css(colors.onSurfaceVariant);
    var card = _css(colors.surfaceContainerHighest);
    var line = _css(colors.outlineVariant);
    return HtmlWidget(
      bodyHtml,
      baseUrl: baseUrl,
      // Small documents: built at once, which keeps the view stable.
      buildAsync: false,
      textStyle: theme.textTheme.bodyLarge,
      onTapUrl: (url) {
        if (url.startsWith('#')) {
          // An anchor, scrolled to by the widget.
          return false;
        }
        _tap(url);
        return true;
      },
      customWidgetBuilder: (element) {
        if (element.localName == 'header' &&
            element.classes.contains('site-header')) {
          return _SiteHeader(element: element, onLink: _tap);
        }
        if (element.localName == 'ul' && element.classes.contains('cards')) {
          return _Cards(element: element, baseUrl: baseUrl, onLink: _tap);
        }
        return null;
      },
      customStylesBuilder: (element) {
        var classes = element.classes;
        var tag = element.localName;
        if (monospaceFontFamily != null &&
            (tag == 'pre' || tag == 'code' || tag == 'tt')) {
          // Quoted: a family name can hold spaces (`JetBrains Mono`).
          return {'font-family': "'$monospaceFontFamily', monospace"};
        }
        if (tag == 'th' || tag == 'td') {
          return {
            'padding': '6px 12px',
            'border-bottom': '1px solid $line',
            'vertical-align': 'top',
          };
        }
        if (tag == 'blockquote') {
          return {
            'margin': '16px 0',
            'padding': '4px 16px',
            'border-left': '3px solid $line',
            'color': muted,
          };
        }
        if (classes.contains('summary')) {
          return {'color': muted, 'font-size': '1.15em'};
        }
        if (classes.contains('meta') || element.localName == 'figcaption') {
          return {'color': muted, 'font-size': '0.9em'};
        }
        if (classes.contains('details')) {
          return {
            'background-color': card,
            'padding': '12px 16px',
            'border-radius': '8px',
          };
        }
        if (element.localName == 'dt' &&
            element.parent?.classes.contains('details') == true) {
          return {'font-weight': '600'};
        }
        if (classes.contains('tag')) {
          return {
            'background-color': card,
            'padding': '2px 10px',
            'border-radius': '12px',
            'font-size': '0.85em',
          };
        }
        if (classes.contains('site-footer')) {
          return {
            'color': muted,
            'font-size': '0.9em',
            'border-top': '1px solid $line',
            'margin-top': '24px',
            'padding-top': '8px',
          };
        }
        return null;
      },
    );
  }
}

/// The site name and the navigation, as a bar.
class _SiteHeader extends StatelessWidget {
  final dom.Element element;
  final CmsHtmlLinkCallback onLink;

  const _SiteHeader({required this.element, required this.onLink});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var siteName = element.querySelector('a.site-name');
    var links = element.querySelectorAll('ul a');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 8),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (siteName != null)
            InkWell(
              onTap: () => onLink(siteName.attributes['href'] ?? ''),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  siteName.text.trim(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 16),
          for (var link in links)
            TextButton(
              onPressed: () => onLink(link.attributes['href'] ?? ''),
              child: Text(link.text.trim()),
            ),
        ],
      ),
    );
  }
}

/// The page cards of the index.
class _Cards extends StatelessWidget {
  final dom.Element element;
  final Uri? baseUrl;
  final CmsHtmlLinkCallback onLink;

  const _Cards({
    required this.element,
    required this.baseUrl,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var cards = element.querySelectorAll('li.card > a');
    return LayoutBuilder(
      builder: (context, constraints) {
        // As the css does: as many 16rem columns as fit.
        var columns = (constraints.maxWidth / 256).floor().clamp(1, 4);
        var width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var card in cards)
              SizedBox(
                width: width,
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onLink(card.attributes['href'] ?? ''),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (card.querySelector('img')?.attributes['src']
                            case var src?)
                          Image.network(
                            (baseUrl?.resolve(src) ?? Uri.parse(src))
                                .toString(),
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.querySelector('h2')?.text.trim() ?? '',
                                style: theme.textTheme.titleMedium,
                              ),
                              if (card.querySelector('p')?.text.trim()
                                  case var summary? when summary.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    summary,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

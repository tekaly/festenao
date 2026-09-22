import 'package:festenao_cms_flutter/src/html_frame/cms_html_frame_common.dart';
import 'package:festenao_cms_flutter/src/html_frame/cms_html_iframe_web.dart';
import 'package:festenao_cms_flutter/src/widget/cms_rendered_html_view.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// True where the browser renders the html itself: on the web only.
const cmsHtmlFrameSupported = true;

/// A generated html document drawn by the browser itself, in a sandboxed
/// iframe: its scripts run in an opaque origin (nothing of the app is
/// reachable from them), the taps on its links are handed to [onLink].
///
/// Only on the web; elsewhere a placeholder says so.
class CmsHtmlFrame extends StatefulWidget {
  /// The document, see `cmsHtmlForBrowser`.
  final String html;

  /// Called with the href of a tapped link.
  final CmsHtmlLinkCallback? onLink;

  /// A frame on [html].
  const CmsHtmlFrame({super.key, required this.html, this.onLink});

  @override
  State<CmsHtmlFrame> createState() => _CmsHtmlFrameState();
}

class _CmsHtmlFrameState extends State<CmsHtmlFrame> {
  /// A new document is a new iframe, see `setUpCmsHtmlIFrame`.
  var _generation = 0;

  /// Stops listening to the current iframe.
  void Function()? _release;

  @override
  void didUpdateWidget(covariant CmsHtmlFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _generation++;
    }
  }

  @override
  void dispose() {
    _release?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    key: ValueKey(_generation),
    tagName: 'iframe',
    onElementCreated: (element) {
      _release?.call();
      _release = setUpCmsHtmlIFrame(
        element as web.HTMLIFrameElement,
        widget.html,
        () => mounted ? widget.onLink : null,
      );
    },
  );
}

class _CmsHtmlWindow implements CmsHtmlWindow {
  final web.Window window;
  web.HTMLIFrameElement? _frame;
  void Function()? _release;

  _CmsHtmlWindow(this.window);

  @override
  bool get isClosed => window.closed;

  @override
  void show(String html, {String? title, CmsHtmlLinkCallback? onLink}) {
    if (isClosed) {
      return;
    }
    var document = window.document;
    if (title != null) {
      document.title = title;
    }
    var frame = document.createElement('iframe') as web.HTMLIFrameElement;
    _release?.call();
    _release = setUpCmsHtmlIFrame(frame, html, () => onLink);
    _frame?.remove();
    _frame = frame;
    document.body?.appendChild(frame);
  }
}

/// Opens a new browser tab to show generated html in, null when not on the
/// web or when the browser blocked it.
///
/// Call it from a tap: browsers only open a tab in answer to one.
CmsHtmlWindow? cmsOpenHtmlWindow({String? title}) {
  var window = web.window.open('', '_blank');
  if (window == null) {
    return null;
  }
  var document = window.document;
  document.title = title ?? '';
  var style = document.createElement('style');
  style.textContent = 'html,body{margin:0;height:100%;overflow:hidden}';
  document.head?.appendChild(style);
  return _CmsHtmlWindow(window);
}

/// Opens [url] in a new browser tab (on the web only).
void cmsOpenExternalUrl(Uri url) {
  web.window.open(url.toString(), '_blank', 'noopener,noreferrer');
}

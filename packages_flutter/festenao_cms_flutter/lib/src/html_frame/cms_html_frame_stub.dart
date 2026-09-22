import 'package:festenao_cms_flutter/src/html_frame/cms_html_frame_common.dart';
import 'package:festenao_cms_flutter/src/widget/cms_rendered_html_view.dart';
import 'package:flutter/material.dart';

/// True where the browser renders the html itself: on the web only.
const cmsHtmlFrameSupported = false;

/// A generated html document drawn by the browser itself, in a sandboxed
/// iframe: its scripts run in an opaque origin (nothing of the app is
/// reachable from them), the taps on its links are handed to [onLink].
///
/// Only on the web; elsewhere a placeholder says so.
class CmsHtmlFrame extends StatelessWidget {
  /// The document, see `cmsHtmlForBrowser`.
  final String html;

  /// Called with the href of a tapped link.
  final CmsHtmlLinkCallback? onLink;

  /// A frame on [html].
  const CmsHtmlFrame({super.key, required this.html, this.onLink});

  @override
  Widget build(BuildContext context) => const Center(
    child: Text('The browser rendering is only available on the web.'),
  );
}

/// Opens a new browser tab to show generated html in, null when not on the
/// web or when the browser blocked it.
///
/// Call it from a tap: browsers only open a tab in answer to one.
CmsHtmlWindow? cmsOpenHtmlWindow({String? title}) => null;

/// Opens [url] in a new browser tab (on the web only).
void cmsOpenExternalUrl(Uri url) {}

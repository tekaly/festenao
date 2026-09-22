import 'package:festenao_cms_flutter/src/widget/cms_rendered_html_view.dart';

/// A browser tab showing generated html documents (see `cmsOpenHtmlWindow`).
abstract class CmsHtmlWindow {
  /// True once the reader closed it.
  bool get isClosed;

  /// Shows [html] (with its `<base>`, see `cmsHtmlForBrowser`), titled
  /// [title]; a tapped link is handed to [onLink] rather than followed.
  void show(String html, {String? title, CmsHtmlLinkCallback? onLink});
}

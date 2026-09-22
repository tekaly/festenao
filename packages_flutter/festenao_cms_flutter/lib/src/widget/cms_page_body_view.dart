import 'package:festenao_cms_flutter/src/widget/cms_rendered_html_view.dart';
import 'package:festenao_common/festenao_cms.dart';
import 'package:festenao_markdown/markdown_plus.dart';
import 'package:flutter/material.dart';

/// The body of a page as the reader sees it: markdown rendered with
/// festenao_markdown, an html body rendered as widgets.
class CmsPageBodyView extends StatelessWidget {
  /// The page.
  final SdbCmsPage page;

  /// Whether the body scrolls on its own (false when embedded in a scroll
  /// view).
  final bool shrinkWrap;

  /// A body view.
  const CmsPageBodyView({
    super.key,
    required this.page,
    this.shrinkWrap = true,
  });

  @override
  Widget build(BuildContext context) {
    var body = page.body.v ?? '';
    if (!page.isMarkdown) {
      return CmsRenderedHtmlView(bodyHtml: body);
    }
    return FestenaoMarkdownWidget(data: body, shrinkWrap: shrinkWrap);
  }
}

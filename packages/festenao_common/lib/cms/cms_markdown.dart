import 'package:markdown/markdown.dart' as md;

/// Render markdown to html (GitHub flavored, tables and strike through
/// included).
///
/// The output is trusted as much as the input: pages are authored by the
/// entity admins, not by visitors, so raw html in the markdown passes through
/// (like a WordPress editor would let it).
String cmsMarkdownToHtml(String markdown) => md.markdownToHtml(
  markdown,
  extensionSet: md.ExtensionSet.gitHubWeb,
  encodeHtml: true,
);

final _markdownSyntaxRegExp = RegExp(r'[#*_`>\[\]()!~]');
final _linkRegExp = RegExp(r'\[([^\]]*)\]\([^)]*\)');
final _imageRegExp = RegExp(r'!\[([^\]]*)\]\([^)]*\)');
final _whitespaceRegExp = RegExp(r'\s+');

/// A plain text excerpt of [markdown], at most [maxLength] characters, cut at
/// a word boundary with an ellipsis.
///
/// Used as the default meta description when a page has no summary.
String cmsMarkdownExcerpt(String markdown, {int maxLength = 160}) {
  var text = markdown
      .replaceAll(_imageRegExp, '')
      .replaceAllMapped(_linkRegExp, (match) => match.group(1) ?? '')
      .replaceAll(_markdownSyntaxRegExp, '')
      .replaceAll(_whitespaceRegExp, ' ')
      .trim();
  if (text.length <= maxLength) {
    return text;
  }
  var cut = text.substring(0, maxLength);
  var lastSpace = cut.lastIndexOf(' ');
  if (lastSpace > maxLength ~/ 2) {
    cut = cut.substring(0, lastSpace);
  }
  return '$cut…';
}

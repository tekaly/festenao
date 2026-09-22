import 'package:festenao_cms_flutter/src/provider/cms_page_providers.dart';
import 'package:festenao_cms_flutter/src/screen/cms_site_browser_screen.dart';
import 'package:festenao_cms_flutter/src/widget/cms_page_body_view.dart';
import 'package:festenao_common/festenao_cms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A page as the reader sees it (title, summary, body, tags).
class CmsPagePreviewScreen extends ConsumerWidget {
  /// The page id.
  final String pageId;

  /// Called to edit the page (an edit button shows when set).
  final void Function(BuildContext context, String pageId)? onEditPage;

  /// Called to show the html the page renders to (a button shows when set,
  /// typically pushing a [CmsSiteBrowserScreen] on the page path).
  final void Function(BuildContext context, SdbCmsPage page)? onViewHtml;

  /// A preview screen.
  const CmsPagePreviewScreen({
    super.key,
    required this.pageId,
    this.onEditPage,
    this.onViewHtml,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var pageAsync = ref.watch(cmsPageProvider(pageId));
    var page = pageAsync.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(page?.title.v ?? 'Page'),
        actions: [
          if (page != null && onViewHtml != null)
            IconButton(
              icon: const Icon(Icons.language),
              tooltip: 'View the generated html',
              onPressed: () => onViewHtml!(context, page),
            ),
          if (onEditPage != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: () => onEditPage!(context, pageId),
            ),
        ],
      ),
      body: pageAsync.when(
        data: (page) {
          if (page == null) {
            return const Center(child: Text('Page not found'));
          }
          return CmsPageView(page: page);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

/// The reader view of a page (no scaffold), reused by the editor preview.
class CmsPageView extends StatelessWidget {
  /// The page.
  final SdbCmsPage page;

  /// A page view.
  const CmsPageView({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var summary = page.summary.v;
    var tags = page.tags.v ?? const <String>[];
    var heroUrl = page.heroImage.v?.url.v;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!page.isPublished)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Chip(
              label: const Text('Draft'),
              avatar: const Icon(Icons.visibility_off, size: 16),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        Text(page.title.v ?? '', style: theme.textTheme.headlineMedium),
        if (summary != null && summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              summary,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (heroUrl != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                heroUrl,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        const SizedBox(height: 12),
        CmsPageBodyView(page: page),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Wrap(
              spacing: 8,
              children: [for (var tag in tags) Chip(label: Text(tag))],
            ),
          ),
      ],
    );
  }
}

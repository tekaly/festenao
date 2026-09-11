import 'package:festenao_cms_flutter/src/provider/cms_page_providers.dart';
import 'package:festenao_cms_flutter/src/screen/cms_page_edit_screen.dart';
import 'package:festenao_common/festenao_cms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The pages of a content database: open, publish, create, delete.
///
/// Reads the database from [cmsPageSdbProvider]. Navigation defaults to
/// [Navigator] pushes of [CmsPageEditScreen]; a router host gives
/// [onOpenPage] and [onCreatePage] instead.
class CmsPagesScreen extends ConsumerWidget {
  /// App bar title.
  final String title;

  /// Called when a page is tapped; defaults to pushing the edit screen.
  final void Function(BuildContext context, SdbCmsPage page)? onOpenPage;

  /// Called by the create button; defaults to pushing the edit screen.
  final void Function(BuildContext context)? onCreatePage;

  /// Whether the create button shows (false for a read only member).
  final bool canEdit;

  /// A page list screen.
  const CmsPagesScreen({
    super.key,
    this.title = 'Pages',
    this.onOpenPage,
    this.onCreatePage,
    this.canEdit = true,
  });

  void _open(BuildContext context, WidgetRef ref, SdbCmsPage page) {
    var onOpenPage = this.onOpenPage;
    if (onOpenPage != null) {
      onOpenPage(context, page);
      return;
    }
    var sdb = ref.read(cmsPageSdbProvider);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => cmsPageSdbScope(
          sdb: sdb,
          child: CmsPageEditScreen(pageId: page.id, readOnly: !canEdit),
        ),
      ),
    );
  }

  void _create(BuildContext context, WidgetRef ref) {
    var onCreatePage = this.onCreatePage;
    if (onCreatePage != null) {
      onCreatePage(context);
      return;
    }
    var sdb = ref.read(cmsPageSdbProvider);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => cmsPageSdbScope(
          sdb: sdb,
          child: const CmsPageEditScreen(pageId: null),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var pagesAsync = ref.watch(cmsPagesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: pagesAsync.when(
        data: (pages) {
          if (pages.isEmpty) {
            return Center(
              child: Text(
                canEdit ? 'No page yet, create one.' : 'No page yet.',
              ),
            );
          }
          return ListView.builder(
            itemCount: pages.length,
            itemBuilder: (context, index) {
              var page = pages[index];
              var published = page.isPublished;
              return ListTile(
                leading: Icon(_kindIcon(page.kind)),
                title: Text(page.title.v ?? '(no title)'),
                subtitle: Text(
                  ['/${page.slug.v ?? ''}', ?page.summary.v].join(' — '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: canEdit
                    ? Switch(
                        value: published,
                        onChanged: (value) => ref
                            .read(cmsPageSdbProvider)
                            .setPublished(page.id, value),
                      )
                    : Icon(
                        published ? Icons.public : Icons.visibility_off,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                onTap: () => _open(context, ref, page),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _create(context, ref),
              tooltip: 'New page',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  static IconData _kindIcon(String kind) => switch (kind) {
    cmsItemKindLocation => Icons.place_outlined,
    cmsItemKindActivity => Icons.directions_run,
    cmsItemKindEvent => Icons.event,
    cmsItemKindOffer => Icons.sell_outlined,
    _ => Icons.article_outlined,
  };
}

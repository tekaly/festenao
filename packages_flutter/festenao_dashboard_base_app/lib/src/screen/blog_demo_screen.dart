import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_dashboard_base_app/src/provider/blog_providers.dart';
import 'package:festenao_dashboard_base_app/src/provider/route_scope_providers.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Blog demo screen.
///
/// Displays blog entries stored in a local [BlogSdb] that is synchronized
/// with Firestore at `app/<app>/project/<projectId>/data/blog`.
///
/// Takes no argument: the project and data ids come from
/// [currentProjectIdProvider] and [currentDataIdProvider], which the route tree
/// scopes from the location (`dashboardProjectScopeRoute` /
/// `dashboardFixedDataScopeRoute`). `LegacyBlogDemoScreen` is the same screen
/// with the ids passed down explicitly.
class BlogDemoScreen extends ConsumerWidget {
  static const routeName = 'blog_demo';

  /// The part below `/project/:project_id`, see `blogDemoPath`.
  static const routeLocationPart = 'blog_demo';

  /// The data id this screen works on, whatever the location says.
  static const blogDataId = 'blog';

  const BlogDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var projectId = ref.watch(currentProjectIdProvider);
    var dataId = ref.watch(currentDataIdProvider);
    var entries = ref.watch(blogEntriesProvider(projectId, dataId));
    var contentAsync = ref.watch(blogContentProvider(projectId, dataId));

    return Scaffold(
      appBar: AppBar(
        // Mounted at the top level, so a deep link has no parent page to
        // pop to: this button goes up instead.
        leading: RouteUpBackButton(upPath: dashboardProjectPath),
        title: Text('Blog – $projectId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync with Firestore',
            onPressed: contentAsync.hasValue
                ? () async {
                    await contentAsync.value!.synchronize();
                  }
                : null,
          ),
        ],
      ),
      body: entries.when(
        data: (blogs) {
          if (blogs.isEmpty) {
            return const Center(child: Text('No blog entries yet'));
          }
          return ListView.builder(
            itemCount: blogs.length,
            itemBuilder: (context, index) {
              final blog = blogs[index];
              return ListTile(
                title: Text(blog.title.v ?? '(no title)'),
                subtitle: Text(blog.content.v ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    var sdb = ref
                        .read(blogSdbProvider(projectId, dataId))
                        .value;
                    await sdb?.deleteBlog(blog.id);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref, projectId, dataId),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog(
    BuildContext context,
    WidgetRef ref,
    String projectId,
    String dataId,
  ) async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Blog Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: contentCtrl,
              decoration: const InputDecoration(labelText: 'Content'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final blog = DbBlog()
                ..title.v = titleCtrl.text
                ..content.v = contentCtrl.text
                ..timestamp.v = SdbTimestamp.now();
              var sdb = ref.read(blogSdbProvider(projectId, dataId)).value;
              await sdb?.addBlog(blog);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_dashboard_base_app/src/provider/blog_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Blog demo screen.
///
/// Displays blog entries stored in a local [BlogSdb] that is synchronized
/// with Firestore at `app/<app>/project/<projectId>/data/blog`.
class BlogDemoScreen extends ConsumerStatefulWidget {
  static const routeName = 'blog_demo';
  static const routeLocation = '/project/:project_id/blog_demo';
  static const projectIdPathParameter = 'project_id';
  static String location(String projectId) => '/project/$projectId/blog_demo';

  /// Project id whose blog data is shown.
  final String projectId;

  /// Data id used as the Firestore sub-path and local db name segment.
  final String dataId;

  const BlogDemoScreen({
    super.key,
    required this.projectId,
    this.dataId = 'blog',
  });

  @override
  ConsumerState<BlogDemoScreen> createState() => _BlogDemoScreenState();
}

class _BlogDemoScreenState extends ConsumerState<BlogDemoScreen> {
  @override
  Widget build(BuildContext context) {
    var entries = ref.watch(
      blogEntriesProvider(widget.projectId, widget.dataId),
    );
    var contentAsync = ref.watch(
      blogContentProvider(widget.projectId, widget.dataId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Blog – ${widget.projectId}'),
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
                        .read(blogSdbProvider(widget.projectId, widget.dataId))
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
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
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
              var sdb = ref
                  .read(blogSdbProvider(widget.projectId, widget.dataId))
                  .value;
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

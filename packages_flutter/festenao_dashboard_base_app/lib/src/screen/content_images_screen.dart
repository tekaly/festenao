import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_blog_demo_providers.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_providers.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_image_edit_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_image_screen.dart';
import 'package:flutter/material.dart';
import 'package:festenao_base_app/blurhash/flutter_blurhash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ContentImagesScreen extends ConsumerWidget {
  static const routeName = 'content_images';
  static const routeLocation = '/project/:project_id/data/:data_id/images';
  static const routeLocationPart = 'images';

  static String location(
    String projectId, [
    String? dataId = SdbProjectContent.defaultDataId,
  ]) => '/project/$projectId/data/$dataId/images';

  final String projectId;
  final String dataId;

  const ContentImagesScreen({
    super.key,
    required this.projectId,
    String? dataId,
  }) : dataId = dataId ?? SdbProjectContent.defaultDataId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(imageEntriesProvider(projectId, dataId));
    final contentAsync = ref.watch(projectContentProvider(projectId, dataId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Images'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync with Firestore',
            onPressed: contentAsync.hasValue
                ? () => contentAsync.value!.synchronize()
                : null,
          ),
        ],
      ),
      body: imagesAsync.when(
        data: (images) {
          if (images.isEmpty) {
            return const Center(child: Text('No images yet'));
          }
          return ListView.builder(
            itemCount: images.length,
            itemBuilder: (context, i) {
              final img = images[i];
              return ListTile(
                leading: img.blurHash.v != null
                    ? SizedBox(
                        width: 48,
                        height: 48,
                        child: BlurHash(hash: img.blurHash.v!),
                      )
                    : const Icon(Icons.image_outlined),
                title: Text(img.name.v ?? '(no name)'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(img.id, style: TextStyle(fontSize: 8)),
                    if (img.copyright.v != null) Text('© ${img.copyright.v}'),
                  ],
                ),
                onTap: () => goToContentImageScreen(
                  context,
                  projectId: projectId,
                  dataId: dataId,
                  imageId: img.ref.key,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final sdb = ref
                        .read(contentSdbProvider(projectId, dataId))
                        .value;
                    await sdb?.deleteImage(img.ref.key);
                    await sdb?.mediaDb.deleteMediaFile(img.ref.key);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => goToContentImageEditScreen(
          context,
          projectId: projectId,
          dataId: dataId,
          imageId: null,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> goToContentImagesScreen(
  BuildContext context, {
  required String projectId,
  required String dataId,
}) async {
  await context.push<void>(ContentImagesScreen.location(projectId, dataId));
}

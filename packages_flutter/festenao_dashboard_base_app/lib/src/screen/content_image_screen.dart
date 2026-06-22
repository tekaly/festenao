import 'dart:typed_data';

import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_providers.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_image_edit_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_media_screen.dart';
import 'package:flutter/material.dart';
import 'package:festenao_base_app/blurhash/flutter_blurhash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ContentImageScreen extends ConsumerWidget {
  static const routeName = 'content_image';
  static const routeLocationPart = 'view';
  static const projectIdPathParameter = 'project_id';
  static const dataIdPathParameter = 'data_id';
  static const imageIdPathParameter = 'image_id';

  static String location(String projectId, String dataId, String imageId) =>
      '/project/$projectId/data/$dataId/image/$imageId/view';

  final String projectId;
  final String dataId;
  final String imageId;

  const ContentImageScreen({
    super.key,
    required this.projectId,
    required this.dataId,
    required this.imageId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageAsync = ref.watch(
      imageEntryProvider(projectId, dataId, imageId),
    );
    final contentSdb = ref.watch(contentSdbProvider(projectId, dataId)).value;
    final projectContent = ref
        .watch(projectContentProvider(projectId, dataId))
        .value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync with Firestore',
            onPressed: projectContent != null
                ? () => projectContent.synchronize()
                : null,
          ),
        ],
      ),
      body: imageAsync.when(
        data: (image) {
          if (image == null) {
            return const ListTile(title: Text('Not found'));
          }
          final aspectRatio = ((image.width.v ?? 1) / (image.height.v ?? 1))
              .toDouble();
          return ListView(
            children: [
              ListTile(title: const Text('ID'), subtitle: Text(image.ref.key)),
              ListTile(
                title: const Text('Name'),
                subtitle: Text(image.name.v ?? '?'),
              ),
              ListTile(
                title: const Text('Copyright'),
                subtitle: Text(image.copyright.v ?? '?'),
              ),
              ListTile(
                title: const Text('Size'),
                subtitle: Text(
                  '${image.width.v ?? '?'}x${image.height.v ?? '?'}',
                ),
              ),
              ListTile(
                title: const Text('Media ID'),
                subtitle: Text(image.mediaId.v ?? imageId),
                trailing: IconButton(
                  icon: const Icon(Icons.arrow_right_rounded),
                  onPressed: () {
                    var mediaId = image.mediaId.v ?? imageId;
                    goToContentMediaScreen(
                      context,
                      projectId: projectId,
                      dataId: dataId,
                      mediaId: mediaId,
                    );
                  },
                ),
              ),
              ListTile(
                title: const Text('Blurhash'),
                subtitle: Text(image.blurHash.v ?? '?'),
              ),
              if (image.blurHash.v != null)
                SizedBox(
                  height: 128,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: BlurHash(hash: image.blurHash.v!),
                    ),
                  ),
                ),
              Consumer(
                builder: (context, ref, _) {
                  var mediaId = image.mediaId.v ?? imageId;
                  final mediaFileAsync = ref.watch(
                    mediaEntryProvider(projectId, dataId, mediaId),
                  );
                  final mediaFileStatusAsync = ref.watch(
                    mediaStatusFileEntryProvider(projectId, dataId, mediaId),
                  );

                  return Column(
                    children: [
                      mediaFileStatusAsync.maybeWhen(
                        data: (status) {
                          if (status == null) return const SizedBox.shrink();
                          var local = status.local.v == 1;
                          var remote = status.remote.v == 1;
                          return ListTile(
                            title: const Text('Media file sync status'),
                            subtitle: Text(
                              '${local ? 'Local' : 'Missing local'} / ${remote ? 'Remote' : 'Missing remote'}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    if (contentSdb != null) {
                                      await contentSdb.mediaDb
                                          .markStatusCleared(mediaId);
                                    }
                                  },
                                  icon: Icon(Icons.refresh),
                                ),
                              ],
                            ),
                          );
                        },
                        orElse: () => const SizedBox.shrink(),
                      ),
                      mediaFileAsync.when(
                        data: (mediaFile) {
                          if (mediaFile == null) {
                            return const ListTile(
                              title: Text('Media file not found'),
                            );
                          }
                          return Column(
                            children: [
                              ListTile(
                                title: const Text('Media MIME type'),
                                subtitle: Text(mediaFile.type.v ?? '?'),
                              ),

                              FutureBuilder<Uint8List?>(
                                future: ref
                                    .read(contentSdbProvider(projectId, dataId))
                                    .maybeWhen(
                                      data: (sdb) => sdb != null
                                          ? _loadMediaBytes(sdb, mediaId)
                                          : null,
                                      orElse: () => null,
                                    ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox(
                                      height: 64,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  final bytes = snapshot.data;
                                  if (bytes == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return SizedBox(
                                    height: 340,
                                    child: Center(
                                      child: AspectRatio(
                                        aspectRatio: aspectRatio,
                                        child: Image.memory(bytes),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                        loading: () => const SizedBox(
                          height: 64,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: imageAsync.value != null
          ? FloatingActionButton(
              onPressed: () async {
                await goToContentImageEditScreen(
                  context,
                  projectId: projectId,
                  dataId: dataId,
                  imageId: imageId,
                );
              },
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }
}

Future<Uint8List?> _loadMediaBytes(SdfContentSdb sdb, String imageId) async {
  try {
    return await sdb.mediaDb.readMediaFileBytes(imageId);
  } catch (_) {
    return null;
  }
}

Future<void> goToContentImageScreen(
  BuildContext context, {
  required String projectId,
  required String dataId,
  required String imageId,
}) async {
  await context.push<void>(
    ContentImageScreen.location(projectId, dataId, imageId),
  );
}

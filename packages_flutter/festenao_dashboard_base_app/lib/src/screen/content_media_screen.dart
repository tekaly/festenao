import 'package:festenao_base_app/import/ui.dart';
import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:festenao_common/data/festenao_media_source_firebase.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_providers.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_media_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:tekartik_app_url_launcher_flutter/web_launch_uri.dart';

class ContentMediaScreen extends HookConsumerWidget {
  static const routeName = 'content_media';
  static const routeLocation =
      '/project/:project_id/data/:data_id/media/:media_id';
  static const projectIdPathParameter = 'project_id';
  static const dataIdPathParameter = 'data_id';
  static const mediaIdPathParameter = 'media_id';

  static String location(String projectId, String dataId, String mediaId) =>
      '/project/$projectId/data/$dataId/media/$mediaId';

  final String projectId;
  final String dataId;
  final String mediaId;

  const ContentMediaScreen({
    super.key,
    required this.projectId,
    required this.dataId,
    required this.mediaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(
      mediaEntryProvider(projectId, dataId, mediaId),
    );
    final mediaStatusAsync = ref.watch(
      mediaStatusFileEntryProvider(projectId, dataId, mediaId),
    );

    final projectContent = ref
        .watch(sdbProjectContentProvider(projectId, dataId))
        .value;
    var firebaseSource = castAsOrNull<FestenaoMediaSourceFirebase>(
      projectContent?.mediaSource,
    );

    var mediaDb = projectContent?.contentSdb.mediaDb;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media File'),
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
      body: mediaAsync.when(
        data: (media) {
          if (media == null) {
            return const ListTile(title: Text('Not found'));
          }
          return ListView(
            children: [
              ListTile(title: const Text('ID'), subtitle: Text(media.ref.key)),
              ListTile(
                title: const Text('Filename'),
                subtitle: Text(media.originalFilename.v ?? '?'),
              ),
              ListTile(
                title: const Text('Mime Type'),
                subtitle: Text(media.type.v ?? '?'),
              ),
              ListTile(
                title: const Text('Size'),
                subtitle: Text(
                  media.size.v != null ? _formatBytes(media.size.v!) : '?',
                ),
              ),
              ListTile(
                title: const Text('Path'),
                subtitle: Text(media.path.v ?? '?'),
              ),
              ListTile(
                title: const Text('Uploaded'),
                subtitle: Text(media.uploaded.v?.toString() ?? '?'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (media.uploaded.v == null)
                      IconButton(
                        icon: const Icon(Icons.auto_fix_high),
                        onPressed: () async {
                          await mediaDb?.fixMediaFileRecord(mediaId);
                        },
                      ),
                  ],
                ),
              ),
              ListTile(
                title: const Text('Deleted'),
                subtitle: Text(media.deleted.v?.toString() ?? '?'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (media.deleted.v == null)
                      IconButton(
                        icon: const Icon(Icons.auto_fix_high),
                        onPressed: () async {
                          await mediaDb?.fixMediaFileRecord(mediaId);
                        },
                      ),
                  ],
                ),
              ),
              mediaStatusAsync.maybeWhen(
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
                            if (mediaDb != null) {
                              await mediaDb.markStatusCleared(mediaId);
                            }
                          },
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              ...mediaStatusAsync.when(
                data: (status) => [
                  if (mediaDb != null)
                    FutureBuilder(
                      future: mediaDb.getMediaFile(mediaId),
                      builder: (context, snapshot) {
                        var mediaFile = snapshot.data;
                        if (mediaFile == null) {
                          return const ListTile(
                            title: Text('Media file not found'),
                          );
                        }
                        return FutureBuilder(
                          future: mediaFile.stat(),
                          builder: (context, snapshot) {
                            var stat = snapshot.data;
                            if (stat == null) {
                              return const ListTile(
                                title: Text('Media file stat not found'),
                              );
                            }
                            return ListTile(
                              title: const Text('Media file stat'),
                              subtitle: Text(
                                'Size: ${_formatBytes(stat.size)}, Type: ${stat.type}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Mark to upload',
                                    icon: const Icon(Icons.upload),
                                    onPressed: () async {
                                      await mediaDb.markToUpload(mediaId);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Delete local file',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      var file = await mediaDb.getMediaFile(
                                        mediaId,
                                      );
                                      await file.delete();
                                      if (context.mounted) {
                                        muiSnackSync(
                                          context,
                                          'Trigger sync to re-download the file',
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
                error: (Object error, StackTrace stackTrace) => [
                  ListTile(title: Text('error: $error')),
                ],
                loading: () => [],
              ),
              if (firebaseSource != null && media.path.v != null) ...[
                Builder(
                  builder: (context) {
                    var ref = FestenaoMediaFileRef.fromPath(media.path.v!);
                    var gsUri = firebaseSource.getGsLink(ref: ref);
                    return ListTile(
                      title: const Text('GS Link'),
                      subtitle: Text(gsUri.toString()),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: gsUri.toString()),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('GS Link copied')),
                          );
                        },
                      ),
                    );
                  },
                ),
                FutureBuilder<String>(
                  future: firebaseSource.getDownloadUrl(
                    ref: FestenaoMediaFileRef.fromPath(media.path.v!),
                  ),
                  builder: (context, snapshot) {
                    var url = snapshot.data;
                    return ListTile(
                      title: const Text('Download URL'),
                      subtitle: Text(url ?? '<null>'),
                      trailing: url != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: url));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('URL copied'),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: () => webLaunchUri(Uri.parse(url)),
                                ),
                              ],
                            )
                          : null,
                    );
                  },
                ),
              ],
              const SizedBox(height: 64),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: mediaAsync.value != null
          ? FloatingActionButton(
              onPressed: () async {
                await goToContentMediaEditScreen(
                  context,
                  projectId: projectId,
                  dataId: dataId,
                  mediaId: mediaId,
                );
              },
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

Future<void> goToContentMediaScreen(
  BuildContext context, {
  required String projectId,
  required String dataId,
  required String mediaId,
}) async {
  await context.push<void>(
    ContentMediaScreen.location(projectId, dataId, mediaId),
  );
}

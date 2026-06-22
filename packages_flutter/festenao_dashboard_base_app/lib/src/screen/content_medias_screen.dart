import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_providers.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_router.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_media_edit_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_media_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

extension DashboardGoRouterStateExt on GoRouterState {
  String getProjectId() => pathParameters[DashboardRouter.projectIdParam]!;
  String getDataId() => pathParameters[DashboardRouter.dataIdParam]!;
  String getImageId() => pathParameters[DashboardRouter.imageIdParam]!;
}

class ContentMediasScreen extends HookConsumerWidget {
  static const routeName = 'content_medias';
  static const routeLocation = '/project/:project_id/data/:data_id/medias';
  static const routeLocationPart = 'medias';

  static String location(
    String projectId, [
    String? dataId = SdbProjectContent.defaultDataId,
  ]) => '/project/$projectId/data/$dataId/medias';

  final String projectId;
  final String dataId;

  const ContentMediasScreen({
    super.key,
    required this.projectId,
    String? dataId,
  }) : dataId = dataId ?? SdbProjectContent.defaultDataId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediasAsync = ref.watch(mediaEntriesProvider(projectId, dataId));
    final contentAsync = ref.watch(projectContentProvider(projectId, dataId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Files'),
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
      body: mediasAsync.when(
        data: (medias) {
          final active = medias.where((m) => m.deleted.v != true).toList();
          if (active.isEmpty) {
            return const Center(child: Text('No media files yet'));
          }
          return ListView.builder(
            itemCount: active.length,
            itemBuilder: (context, i) {
              final media = active[i];
              return ListTile(
                leading: _iconForMimeType(media.type.v),
                title: Text(media.originalFilename.v ?? '(no name)'),
                subtitle: Text(_formatInfo(media)),
                onTap: () => goToContentMediaScreen(
                  context,
                  projectId: projectId,
                  dataId: dataId,
                  mediaId: media.ref.key,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final sdb = ref
                        .read(contentSdbProvider(projectId, dataId))
                        .value;
                    await sdb?.mediaDb.deleteMediaFile(media.ref.key);
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
        onPressed: () => goToContentMediaEditScreen(
          context,
          projectId: projectId,
          dataId: dataId,
          mediaId: null,
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _iconForMimeType(String? type) {
    if (type == null) return const Icon(Icons.insert_drive_file_outlined);
    if (type.startsWith('image/')) return const Icon(Icons.image_outlined);
    if (type.startsWith('video/')) return const Icon(Icons.videocam_outlined);
    if (type.startsWith('audio/')) return const Icon(Icons.audiotrack_outlined);
    return const Icon(Icons.insert_drive_file_outlined);
  }

  String _formatInfo(SdbFestenaoMediaFile media) {
    final parts = <String>[];
    parts.add(media.id);
    if (media.type.v != null) parts.add(media.type.v!);
    if (media.size.v != null) parts.add(_formatBytes(media.size.v!));
    return parts.join(' · ');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

Future<void> goToContentMediasScreen(
  BuildContext context, {
  required String projectId,
  required String dataId,
}) async {
  await context.push<void>(ContentMediasScreen.location(projectId, dataId));
}

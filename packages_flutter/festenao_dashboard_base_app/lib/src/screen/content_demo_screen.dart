import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_blog_demo_providers.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screen for managing [SdfArtist], [SdfLocation], [SdfEvent], [SdfImage]
/// entities stored in a synced SDB at
/// `app/<app>/project/<projectId>/data/<dataId>`.
class ContentDemoScreen extends ConsumerStatefulWidget {
  static const routeName = 'content_demo';
  static const routeLocation = '/project/:project_id/content_demo';
  static const projectIdPathParameter = 'project_id';
  static String location(String projectId) =>
      '/project/$projectId/content_demo';

  final String projectId;

  /// Firestore sub-path segment and local db name prefix.
  final String dataId;

  const ContentDemoScreen({
    super.key,
    required this.projectId,
    this.dataId = 'content',
  });

  @override
  ConsumerState<ContentDemoScreen> createState() => _ContentDemoScreenState();
}

class _ContentDemoScreenState extends ConsumerState<ContentDemoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _pid => widget.projectId;
  String get _did => widget.dataId;

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(projectContentProvider(_pid, _did));

    return Scaffold(
      appBar: AppBar(
        title: Text('Content – $_pid'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync with Firestore',
            onPressed: contentAsync.hasValue
                ? () => contentAsync.value!.synchronize()
                : null,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Artists'),
            Tab(icon: Icon(Icons.location_on), text: 'Locations'),
            Tab(icon: Icon(Icons.event), text: 'Events'),
            Tab(icon: Icon(Icons.image), text: 'Images'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ArtistTab(projectId: _pid, dataId: _did),
          _LocationTab(projectId: _pid, dataId: _did),
          _EventTab(projectId: _pid, dataId: _did),
          _ImageTab(projectId: _pid, dataId: _did),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onAdd(context),
        tooltip: 'Add',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _onAdd(BuildContext context) {
    switch (_tabs.index) {
      case 0:
        _showAddArtistDialog(context);
      case 1:
        _showAddLocationDialog(context);
      case 2:
        _showAddEventDialog(context);
      case 3:
        _showAddImageDialog(context);
    }
  }

  // ─── Add dialogs ─────────────────────────────────────────────────────────────

  Future<void> _showAddArtistDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Artist'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final sdb = ref.read(contentSdbProvider(_pid, _did)).value;
              await sdb?.addArtist(SdfArtist()..name.v = nameCtrl.text.trim());
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddLocationDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Location'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final sdb = ref.read(contentSdbProvider(_pid, _did)).value;
              await sdb?.addLocation(
                SdfLocation()..name.v = nameCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEventDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final dayCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            TextField(
              controller: dayCtrl,
              decoration: const InputDecoration(
                labelText: 'Day (YYYY-MM-DD)',
                hintText: '2025-07-14',
              ),
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
              final sdb = ref.read(contentSdbProvider(_pid, _did)).value;
              await sdb?.addEvent(
                SdfEvent()
                  ..name.v = nameCtrl.text.trim()
                  ..day.v = dayCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddImageDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final copyrightCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'File name'),
              autofocus: true,
            ),
            TextField(
              controller: copyrightCtrl,
              decoration: const InputDecoration(labelText: 'Copyright'),
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
              final sdb = ref.read(contentSdbProvider(_pid, _did)).value;
              await sdb?.addImage(
                SdfImage()
                  ..name.v = nameCtrl.text.trim()
                  ..copyright.v = copyrightCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ─── Per-entity tab widgets ───────────────────────────────────────────────────

class _ArtistTab extends ConsumerWidget {
  final String projectId;
  final String dataId;
  const _ArtistTab({required this.projectId, required this.dataId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(artistEntriesProvider(projectId, dataId));
    return entries.when(
      data: (artists) {
        if (artists.isEmpty) {
          return const Center(child: Text('No artists yet'));
        }
        return ListView.builder(
          itemCount: artists.length,
          itemBuilder: (context, i) {
            final a = artists[i];
            return ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(a.name.v ?? '(no name)'),
              subtitle: a.type.v != null ? Text(a.type.v!) : null,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final sdb = ref
                      .read(contentSdbProvider(projectId, dataId))
                      .value;
                  await sdb?.deleteArtist(a.id);
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _LocationTab extends ConsumerWidget {
  final String projectId;
  final String dataId;
  const _LocationTab({required this.projectId, required this.dataId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(locationEntriesProvider(projectId, dataId));
    return entries.when(
      data: (locations) {
        if (locations.isEmpty) {
          return const Center(child: Text('No locations yet'));
        }
        return ListView.builder(
          itemCount: locations.length,
          itemBuilder: (context, i) {
            final l = locations[i];
            return ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(l.name.v ?? '(no name)'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final sdb = ref
                      .read(contentSdbProvider(projectId, dataId))
                      .value;
                  await sdb?.deleteLocation(l.id);
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _EventTab extends ConsumerWidget {
  final String projectId;
  final String dataId;
  const _EventTab({required this.projectId, required this.dataId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(eventEntriesProvider(projectId, dataId));
    return entries.when(
      data: (events) {
        if (events.isEmpty) {
          return const Center(child: Text('No events yet'));
        }
        return ListView.builder(
          itemCount: events.length,
          itemBuilder: (context, i) {
            final e = events[i];
            return ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text(e.name.v ?? '(no name)'),
              subtitle: e.day.v != null ? Text(e.day.v!) : null,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final sdb = ref
                      .read(contentSdbProvider(projectId, dataId))
                      .value;
                  await sdb?.deleteEvent(e.id);
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _ImageTab extends ConsumerWidget {
  final String projectId;
  final String dataId;
  const _ImageTab({required this.projectId, required this.dataId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(imageEntriesProvider(projectId, dataId));
    return entries.when(
      data: (images) {
        if (images.isEmpty) {
          return const Center(child: Text('No images yet'));
        }
        return ListView.builder(
          itemCount: images.length,
          itemBuilder: (context, i) {
            final img = images[i];
            return ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(img.name.v ?? '(no name)'),
              subtitle: img.copyright.v != null
                  ? Text('© ${img.copyright.v}')
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final sdb = ref
                      .read(contentSdbProvider(projectId, dataId))
                      .value;
                  await sdb?.deleteImage(img.id);
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

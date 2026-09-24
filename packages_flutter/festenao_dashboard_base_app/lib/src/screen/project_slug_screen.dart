import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common_flutter/festenao_slug_flutter.dart';
import 'package:festenao_common_flutter/share_link.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/project_slug_providers.dart';

/// The location of the project url [slug] (`/p/<slug>`).
String dashboardProjectSlugLocation(String slug) =>
    '/$festenaoProjectUrlPathSegment/$slug';

/// `/p/:slug`: the url of a project, resolved to the project (following an
/// old slug) and replaced by [projectLocation] of its id.
///
/// The dashboard opens the access screen of the project; a public app opens
/// the project content (festenaoprv user plus app: its blog).
class DashboardProjectSlugScreen extends StatefulWidget {
  /// The slug of the url.
  final String slug;

  /// The location a project id opens.
  final String Function(String projectId) projectLocation;

  /// The database resolving the slug, the global one by default.
  final FestenaoFirestoreDatabase? fsDatabase;

  /// A project url.
  const DashboardProjectSlugScreen({
    super.key,
    required this.slug,
    required this.projectLocation,
    this.fsDatabase,
  });

  @override
  State<DashboardProjectSlugScreen> createState() =>
      _DashboardProjectSlugScreenState();
}

class _DashboardProjectSlugScreenState
    extends State<DashboardProjectSlugScreen> {
  late final Future<String?> _projectId =
      (widget.fsDatabase ?? globalFestenaoFirestoreDatabase).resolveProjectSlug(
        widget.slug.toLowerCase(),
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _projectId,
    builder: (context, snapshot) {
      var projectId = snapshot.data;
      if (projectId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go(widget.projectLocation(projectId));
          }
        });
      }
      Widget body;
      if (snapshot.hasError) {
        body = Text('Could not open /p/${widget.slug}: ${snapshot.error}');
      } else if (snapshot.connectionState == ConnectionState.done &&
          projectId == null) {
        body = Text('No project at /p/${widget.slug}');
      } else {
        body = const CircularProgressIndicator();
      }
      return Scaffold(
        appBar: AppBar(title: Text('/p/${widget.slug}')),
        body: Center(
          child: Padding(padding: const EdgeInsets.all(24), child: body),
        ),
      );
    },
  );
}

/// The url of a project (`<origin>/p/<slug>`) with a copy button, nothing
/// when it has none (or is not a project).
class DashboardProjectUrlTile extends ConsumerWidget {
  /// The firestore id of the entity.
  final String entityId;

  /// The url of a project.
  const DashboardProjectUrlTile({super.key, required this.entityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var slug = ref.watch(dashboardEntitySlugProvider(entityId)).value;
    if (slug == null) {
      return const SizedBox.shrink();
    }
    var link = appShareLink(dashboardProjectSlugLocation(slug));
    return ListTile(
      leading: const Icon(Icons.link),
      title: const Text('Url'),
      subtitle: SelectableText(link),
      trailing: IconButton(
        tooltip: 'Copy',
        icon: const Icon(Icons.copy),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: link));
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(
              context,
            )?.showSnackBar(const SnackBar(content: Text('Link copied')));
          }
        },
      ),
    );
  }
}

/// The url field of a project form: [FestenaoSlugField] checking the
/// availability against the slug registry of [fsDatabase].
class DashboardProjectSlugField extends StatelessWidget {
  /// The edited slug.
  final TextEditingController controller;

  /// The project id, null while creating it.
  final String? projectId;

  /// Its current slug.
  final String? currentSlug;

  /// The database, the global one by default.
  final FestenaoFirestoreDatabase? fsDatabase;

  /// Called whenever the status changes.
  final ValueChanged<FestenaoSlugStatus>? onStatusChanged;

  /// The url field of a project form.
  const DashboardProjectSlugField({
    super.key,
    required this.controller,
    this.projectId,
    this.currentSlug,
    this.fsDatabase,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    var fsDb = fsDatabase ?? globalFestenaoFirestoreDatabase;
    var registry = fsDb.slugRegistry();
    var prefix = appShareLink(
      '$festenaoProjectUrlPathSegment/',
    ).replaceFirst(RegExp(r'^https?://'), '');
    return FestenaoSlugField(
      controller: controller,
      currentSlug: currentSlug,
      prefixText: prefix,
      texts: const FestenaoSlugFieldTexts(label: 'Url (optional)'),
      isAvailable: (slug) => registry.isAvailable(
        slug,
        entityType: festenaoProjectSlugEntityType,
        entityId: projectId,
      ),
      onStatusChanged: onStatusChanged,
    );
  }
}

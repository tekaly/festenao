import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common_flutter/festenao_slug_flutter.dart';
import 'package:festenao_common_flutter/share_link.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/kit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../provider/project_slug_providers.dart';
import 'project_slug_screen.dart';

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _copy(BuildContext context, String link) async {
  await Clipboard.setData(ClipboardData(text: link));
  if (context.mounted) {
    _snack(context, festenaoAdminAppIntl(context).linkCopied);
  }
}

/// True when the user confirms [message], [confirmLabel] in the danger
/// colour.
Future<bool> _confirm(
  BuildContext context, {
  required String message,
  required String confirmLabel,
}) async {
  var intl = festenaoAdminAppIntl(context);
  var t = context.festenao;
  var confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(intl.cancelButtonLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: t.bad),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The shared link of the project url [segment] (a slug, or the project id).
String _projectLink(String segment) =>
    appShareLink(dashboardProjectSlugLocation(segment));

/// The copy button of [link].
Widget _copyButton(BuildContext context, String link) => IconButton(
  tooltip: festenaoAdminAppIntl(context).copyButtonLabel,
  icon: const Icon(Icons.copy, size: 20),
  onPressed: () => _copy(context, link),
);

/// The urls of a project (`/p/<slug>`): the current one first, the others
/// opening it too; without any, the project opens at its id.
///
/// The app admins and the holders of the app `slug` role
/// ([dashboardCanSetSlugProvider]) add one, make one the current url and
/// remove one; the others only read them.
class DashboardProjectSlugsScreen extends ConsumerStatefulWidget {
  /// The project.
  final String projectId;

  /// The urls of [projectId].
  const DashboardProjectSlugsScreen({super.key, required this.projectId});

  @override
  ConsumerState<DashboardProjectSlugsScreen> createState() =>
      _DashboardProjectSlugsScreenState();
}

class _DashboardProjectSlugsScreenState
    extends ConsumerState<DashboardProjectSlugsScreen> {
  final _controller = TextEditingController();
  var _status = FestenaoSlugStatus.empty;
  var _busy = false;

  String get _projectId => widget.projectId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        _snack(context, '$e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _add() async {
    var slug = _controller.text.trim();
    if (slug.isEmpty || !_status.isAcceptable) {
      return;
    }
    await _run(() async {
      await globalFestenaoFirestoreDatabase.addProjectSlug(_projectId, slug);
      _controller.clear();
    });
  }

  Future<void> _makeCurrent(String slug) => _run(
    () => globalFestenaoFirestoreDatabase.setProjectSlug(_projectId, slug),
  );

  Future<void> _remove(String slug) async {
    var intl = festenaoAdminAppIntl(context);
    if (!await _confirm(
      context,
      message: intl.projectUrlRemoveConfirm(_projectLink(slug)),
      confirmLabel: intl.projectUrlRemove,
    )) {
      return;
    }
    await _run(
      () => globalFestenaoFirestoreDatabase.removeProjectSlug(_projectId, slug),
    );
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var t = context.festenao;
    var slugs = ref.watch(dashboardProjectUrlSlugsProvider(_projectId));
    var canSetSlug = ref.watch(dashboardCanSetSlugProvider);
    return Scaffold(
      appBar: AppBar(title: Text(intl.projectUrls)),
      body: slugs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (slugs) => FkPage(
          maxWidth: FestenaoSpace.readingWidth,
          children: [
            FkListCard(
              children: [
                if (slugs.isEmpty)
                  FkRow(
                    leading: const FkIconBox(Icons.tag),
                    title: _projectLink(_projectId),
                    subtitle: intl.projectUrlsNone,
                    trailing: _copyButton(context, _projectLink(_projectId)),
                  ),
                for (var (index, slug) in slugs.indexed)
                  FkRow(
                    leading: const FkIconBox(Icons.link),
                    title: _projectLink(slug),
                    badges: [
                      if (index == 0)
                        FkStatusPill(
                          intl.projectUrlCurrent,
                          status: FkStatus.ok,
                        ),
                    ],
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _copyButton(context, _projectLink(slug)),
                        if (canSetSlug)
                          PopupMenuButton<String>(
                            enabled: !_busy,
                            icon: const Icon(Icons.more_vert, size: 20),
                            itemBuilder: (_) => [
                              if (index != 0)
                                PopupMenuItem(
                                  value: 'current',
                                  child: Text(intl.projectUrlMakeCurrent),
                                ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text(intl.projectUrlRemove),
                              ),
                            ],
                            onSelected: (action) => action == 'current'
                                ? _makeCurrent(slug)
                                : _remove(slug),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: FestenaoSpace.xl),
            if (canSetSlug)
              FkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DashboardProjectSlugField(
                      controller: _controller,
                      projectId: _projectId,
                      onStatusChanged: (status) {
                        setState(() {
                          _status = status;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton.icon(
                        onPressed: _busy || !_status.isAcceptable ? null : _add,
                        icon: const Icon(Icons.add_link),
                        label: Text(intl.projectUrlAdd),
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(intl.projectUrlNotAllowed, style: TextStyle(color: t.ink3)),
          ],
        ),
      ),
    );
  }
}

/// Opens the urls of [projectId].
Future<void> goToDashboardProjectSlugsScreen(
  BuildContext context, {
  required String projectId,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => DashboardProjectSlugsScreen(projectId: projectId),
  ),
);

/// `/slugs`: every url in use in the app (the app admins, as the rules
/// allow): the slug, what it opens, current or alias; a project slug opens
/// the project, any slug can be released.
class DashboardSlugsScreen extends ConsumerWidget {
  /// Every url in use in the app.
  const DashboardSlugsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var intl = festenaoAdminAppIntl(context);
    var slugs = ref.watch(dashboardAppSlugsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(intl.slugsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardAppSlugsProvider),
          ),
        ],
      ),
      body: slugs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$error'),
          ),
        ),
        data: (slugs) => FkPage(
          maxWidth: FestenaoSpace.readingWidth,
          children: [
            if (slugs.isEmpty)
              FkCard(
                child: FkEmpty(icon: Icons.link_off, message: intl.slugsEmpty),
              )
            else
              FkListCard(
                children: [for (var slug in slugs) _SlugRow(slug: slug)],
              ),
          ],
        ),
      ),
    );
  }
}

/// One slug of [DashboardSlugsScreen].
class _SlugRow extends ConsumerWidget {
  final FsFestenaoSlug slug;

  const _SlugRow({required this.slug});

  bool get _isProject => slug.entityType.v == festenaoProjectSlugEntityType;

  Future<void> _release(BuildContext context, WidgetRef ref) async {
    var intl = festenaoAdminAppIntl(context);
    if (!await _confirm(
      context,
      message: intl.slugReleaseConfirm(_projectLink(slug.slug)),
      confirmLabel: intl.slugRelease,
    )) {
      return;
    }
    var fsDb = globalFestenaoFirestoreDatabase;
    var entityType = slug.entityType.v ?? '';
    var entityId = slug.entityId.v ?? '';
    try {
      if (_isProject) {
        try {
          // The project copy of its slugs follows.
          await fsDb.removeProjectSlug(entityId, slug.slug);
        } catch (_) {
          // A project that no longer exists, or not readable.
          await fsDb.slugRegistry().release(
            slug.slug,
            entityType: entityType,
            entityId: entityId,
          );
        }
      } else {
        await fsDb.slugRegistry().release(
          slug.slug,
          entityType: entityType,
          entityId: entityId,
        );
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, '$e');
      }
    }
    ref.invalidate(dashboardAppSlugsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var intl = festenaoAdminAppIntl(context);
    var t = context.festenao;
    var entityId = slug.entityId.v ?? '';
    var name = _isProject
        ? ref.watch(dashboardProjectNameProvider(entityId)).value
        : null;
    return FkRow(
      leading: const FkIconBox(Icons.link),
      title: '/$festenaoProjectUrlPathSegment/${slug.slug}',
      subtitle: [?name, '${slug.entityType.v} $entityId'].join(' · '),
      badges: [
        if (slug.alias.v ?? false)
          FkStatusPill(intl.slugAlias, status: FkStatus.muted),
      ],
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, size: 20, color: t.ink3),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'copy', child: Text(intl.copyButtonLabel)),
          PopupMenuItem(value: 'release', child: Text(intl.slugRelease)),
        ],
        onSelected: (action) => action == 'copy'
            ? _copy(context, _projectLink(slug.slug))
            : _release(context, ref),
      ),
      onTap: _isProject && entityId.isNotEmpty
          ? () => context.pushPath(
              projectAccessPath,
              parameters: {DashboardRouteParams.projectId: entityId},
            )
          : null,
    );
  }
}

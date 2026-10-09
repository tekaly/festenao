import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekaly_sdb_synced/synced_sdb.dart';

/// The synchronization of the content of a project, as an app bar action:
/// its state (a spinner while it runs, a warning once it failed) and a tap
/// to synchronize now.
///
/// The content synchronizes by itself; the button shows where it stands and
/// lets the user force it (after being offline for instance).
class ProjectContentSyncButton extends ConsumerWidget {
  /// The project.
  final String projectId;

  /// The data id of the content.
  final String dataId;

  /// The synchronization of the content of [projectId].
  const ProjectContentSyncButton({
    super.key,
    required this.projectId,
    required this.dataId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var intl = festenaoAdminAppIntl(context);
    var content = ref.watch(projectContentProvider(projectId, dataId)).value;
    var status = ref
        .watch(projectContentSyncStatusProvider(projectId, dataId))
        .value;
    Future<void> sync() async {
      await content!.synchronize();
    }

    switch (status?.activity) {
      case SyncedDbSyncActivity.syncing:
        return IconButton(
          tooltip: intl.syncInProgress,
          onPressed: null,
          icon: const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case SyncedDbSyncActivity.failed || SyncedDbSyncActivity.retryScheduled:
        return IconButton(
          tooltip: intl.syncFailed,
          onPressed: content == null ? null : sync,
          icon: Icon(
            Icons.sync_problem,
            color: Theme.of(context).colorScheme.error,
          ),
        );
      default:
        return IconButton(
          tooltip: intl.syncNow,
          onPressed: content == null ? null : sync,
          icon: const Icon(Icons.sync),
        );
    }
  }
}

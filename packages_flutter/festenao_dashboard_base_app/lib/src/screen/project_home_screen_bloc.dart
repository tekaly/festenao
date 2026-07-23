import 'dart:async';

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_audi.dart';

/// The current [SdbUserProject], syncing it once from Firestore (via
/// [UserProjectsSdbSynchronizer]) when it isn't found locally yet.
class ProjectHomeScreenBloc extends AutoDisposeStateBaseBloc<SdbUserProject?> {
  /// The (possibly per user) local projects database.
  final UserProjectsSdb projectsSdb;

  /// Project ID.
  final String projectId;

  // ignore: cancel_subscriptions
  StreamSubscription? _projectSubscription;

  Future<void> _syncProjectMeta(String userId) async {
    var synchronizer = UserProjectsSdbSynchronizer(
      projectsSdb: projectsSdb,
      fsProjects: globalFestenaoFirestoreDatabase.projectDb,
    );
    await synchronizer.syncOne(userId: userId, projectId: projectId);
  }

  /// The current [SdbUserProject], syncing it once from Firestore when it
  /// isn't found locally yet.
  ProjectHomeScreenBloc({required this.projectsSdb, required this.projectId}) {
    audiAddStreamSubscription(
      globalTkCmsFbIdentityBloc.state.listen((state) {
        audiDispose(_projectSubscription);
        var user = state.identity?.user;
        if (user != null) {
          _projectSubscription = audiAddStreamSubscription(
            projectsSdb.onProject(projectId, userId: user.uid).listen((
              project,
            ) async {
              if (project == null) {
                await _syncProjectMeta(user.uid);
                project = await projectsSdb.getProject(
                  projectId,
                  userId: user.uid,
                );
              }
              add(project);
            }),
          );
        } else {
          add(null);
        }
      }),
    );
  }
}

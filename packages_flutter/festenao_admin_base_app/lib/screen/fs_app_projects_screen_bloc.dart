import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/festenao_firestore.dart';

import 'package:tkcms_common/tkcms_auth.dart';

import 'fs_app_view_screen_bloc.dart';

/// Projects screen bloc state
class FsAppProjectsScreenBlocState {
  /// User
  final TkCmsFbIdentity? identity;

  /// Projects
  final List<FsProject> projects;

  /// Projects screen bloc state
  FsAppProjectsScreenBlocState({required this.projects, this.identity});
}

mixin FsAppScreenBlocMixin {}

/// Projects screen bloc
class FsAppProjectsScreenBloc
    extends FsAppBlocBase<FsAppProjectsScreenBlocState> {
  // ignore: cancel_subscriptions

  final bool selectMode;

  @override
  void handleRefresh() {
    var ffdb = this.ffdb;

    /// Build from firestore
    var fsDb = ffdb.projectDb;
    var firestore = ffdb.firestore;
    fsSubscription = audiAddStreamSubscription(
      fsDb.fsEntityCollectionRef.onSnapshotsSupport(firestore).listen((list) {
        fsLock.synchronized(() async {
          add(
            FsAppProjectsScreenBlocState(projects: list, identity: fbIdentity),
          );
          // var ProjectsUser = await dbProjectUserStore.record(userId).get(ProjectsDb.db);
        });
      }),
    );
  }

  @override
  void handleNoIdentity() {
    add(FsAppProjectsScreenBlocState(projects: []));
  }

  /// Projects screen bloc
  FsAppProjectsScreenBloc({this.selectMode = false, super.appId});
}

import 'package:festenao_admin_base_app/screen/fs_app_view_screen_bloc.dart';
import 'package:festenao_common/festenao_firestore.dart';

import 'package:tkcms_common/tkcms_auth.dart';

import 'fs_apps_screen_bloc.dart';

/// Projects screen bloc state
class FsAppUsersScreenBlocState {
  /// User
  final TkCmsFbIdentity? identity;

  /// Projects
  final List<TkCmsFsUserAccess> userAccessList;

  /// Projects screen bloc state
  FsAppUsersScreenBlocState({required this.userAccessList, this.identity});
}

/// Projects screen bloc
class FsAppUsersScreenBloc extends FsAppBlocBase<FsAppUsersScreenBlocState> {
  final bool selectMode;
  final String? projectId;

  @override
  void handleRefresh() {
    /// Build from firestore
    var fsDb = ffdb.appDb;

    var coll = appOrProjectUserAccessCollectionRef(projectId: projectId);
    fsSubscription = audiAddStreamSubscription(
      coll.onSnapshotsSupport(fsDb.firestore).listen((list) {
        fsLock.synchronized(() async {
          add(
            FsAppUsersScreenBlocState(
              identity: fbIdentity,
              userAccessList: list,
            ),
          );
          // var ProjectsUser = await dbProjectUserStore.record(userId).get(ProjectsDb.db);
        });
      }),
    );
  }

  /// Projects screen bloc
  FsAppUsersScreenBloc({this.selectMode = false, super.appId, this.projectId});

  String get appPath => appIdProjectIdAppPath(appIdOrDefault, projectId);
  @override
  void handleNoIdentity() {
    add(FsAppUsersScreenBlocState(identity: null, userAccessList: []));
  }
}

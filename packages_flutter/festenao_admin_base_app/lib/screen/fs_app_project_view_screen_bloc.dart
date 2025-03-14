import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/screen/fs_app_view_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/fs_apps_screen_bloc.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_common_utils/stream/stream_join.dart';
import 'package:tkcms_common/tkcms_auth.dart';

class FsAppProjectViewScreenBlocState {
  final TkCmsFbIdentity? user;

  /// Optional, if the project is not found in the local database
  final FsProject? fsProject;

  /// Project view screen bloc state
  final TkCmsFsUserAccess? fsUserAccess;

  FsAppProjectViewScreenBlocState({
    this.user,
    this.fsProject,
    this.fsUserAccess,
  });
}

class FsAppProjectViewScreenBloc
    extends FsAppBlocBase<FsAppProjectViewScreenBlocState> {
  final String projectId;

  TrackChangesSupportOptionsController? fsController1;
  TrackChangesSupportOptionsController? fsController2;

  FsAppProjectViewScreenBloc({required this.projectId, super.appId});

  String get appPath => appIdProjectIdAppPath(appIdOrDefault, projectId);

  @override
  void handleRefresh() {
    audiDispose(fsController1);
    audiDispose(fsController2);
    fsController1 = audiAddSelf(
      TrackChangesSupportOptionsController(
        refreshDelay: const Duration(minutes: 60),
      ),
      (controller) => controller.dispose(),
    );
    fsController2 = audiAddSelf(
      TrackChangesSupportOptionsController(
        refreshDelay: const Duration(minutes: 60),
      ),
      (controller) => controller.dispose(),
    );
    var ffdb = this.ffdb;
    var fsDb = ffdb.projectDb;
    var firestore = globalFestenaoFirestoreDatabase.firestore;
    fsSubscription = audiAddStreamSubscription(
      streamJoin2OrError(
        fsDb
            .fsEntityRef(projectId)
            .onSnapshotSupport(firestore, options: fsController1),
        (userId != null)
            ? fsDb
                .fsUserEntityAccessRef(userId!, projectId)
                .onSnapshotSupport(firestore, options: fsController2)
            : Stream.value(TkCmsFsUserAccess()),
      ).listen((event) {
        var values = event.values;
        var fsProject = values.$1;
        var fsUserAccess = values.$2;
        add(
          FsAppProjectViewScreenBlocState(
            user: fbIdentity,
            fsProject: fsProject,
            fsUserAccess: fsUserAccess,
          ),
        );
      }),
    );
  }

  @override
  void handleNoIdentity() {
    add(FsAppProjectViewScreenBlocState(user: null));
  }

  Future<void> deleteProject(String projectId) async {
    var ffdb = this.ffdb;
    await ffdb.projectDb.fsEntityRef(projectId).delete(firestore);
  }

  @override
  void refresh() {
    fsController1?.trigger();
    fsController2?.trigger();
  }
}

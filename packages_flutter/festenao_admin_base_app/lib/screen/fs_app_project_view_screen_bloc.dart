import 'dart:async';

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/screen/fs_app_view_screen_bloc.dart';
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

  FsAppProjectViewScreenBloc({required this.projectId, super.appId});

  @override
  void handleRefresh() {
    var ffdb = this.ffdb;
    var fsDb = ffdb.projectDb;
    var firestore = globalFestenaoFirestoreDatabase.firestore;
    fsSubscription = audiAddStreamSubscription(
      streamJoin2OrError(
        fsDb.fsEntityRef(projectId).onSnapshotSupport(firestore),
        (userId != null)
            ? fsDb
                .fsUserEntityAccessRef(userId!, projectId)
                .onSnapshotSupport(firestore)
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
}

import 'package:festenao_admin_base_app/screen/fs_app_view_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';

import 'package:tkcms_common/tkcms_firestore.dart';

class FsAppUserEditScreenParam {
  final String? projectId; // Optional projectId - default is app user
  final String? appId; // Optional appId
  /// Null for creation
  final String? userId;
  FsAppUserEditScreenParam({
    required this.userId,
    this.appId,
    required this.projectId,
  });
}

class FsAppUserEditScreenBlocState {
  final TkCmsFsUserAccess? user;

  FsAppUserEditScreenBlocState(this.user);
}

class FsAppUserEditScreenBloc
    extends FsAppBlocRawBase<FsAppUserEditScreenBlocState> {
  /// Null for creation

  final FsAppUserEditScreenParam param;

  //late StreamSubscription _studiesSubscription;

  FsAppUserEditScreenBloc({required this.param}) : super(appId: param.appId) {
    () async {
      if (!disposed) {
        var userId = param.userId;
        if (userId == null) {
          add(FsAppUserEditScreenBlocState(null));
        } else {
          var userAccessRef = appOrProjectUserAccessCollectionRef(
            projectId: param.projectId,
          ).doc(userId);
          var userAccess = await userAccessRef.get(firestore);
          if (!disposed) {
            add(FsAppUserEditScreenBlocState(userAccess));
          }
        }
      }
    }();
  }
  Future<void> save(AdminUserEditData data) async {
    var userId = data.userId ?? param.userId!;

    var appId = appIdOrDefault;
    var projectId = param.projectId;

    String entityId;
    if (projectId != null) {
      entityId = projectId;
    } else {
      entityId = appId;
    }
    var fsDb = appOrProjectAccess(projectId: projectId);
    var userAccess = data.user;
    userAccess.fixAccess();

    await fsDb.setEntityUserAccess(
      entityId: entityId,
      userId: userId,
      userAccess: userAccess,
    );
    /*
    if (id == null) {
      var existing = await userAccessRef(data.user.userId!).get(fbFirestore);
      if (existing.exists) {
        throw 'User ${data.user.userId!} already exists';
      }
    }
    await userAccessRef(
      data.user.userId!,
    ).set(fbFirestore, data.user, SetOptions(merge: true));*/
  }
}

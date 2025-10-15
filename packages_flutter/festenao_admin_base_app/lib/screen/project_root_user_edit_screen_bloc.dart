import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/screen/project_root_users_screen_bloc.dart';

import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

class AdminProjectUserEditScreenResult {
  final bool deleted;
  final bool modified;

  AdminProjectUserEditScreenResult({
    this.modified = false,
    this.deleted = false,
  });
}

class AdminProjectUserEditScreenParam {
  final String projectId;

  /// Null for creation
  final String? userId;
  AdminProjectUserEditScreenParam({
    required this.userId,
    required this.projectId,
  });
}

class AdminProjectUserEditScreenBlocState {
  final TkCmsEditedFsUserAccess? user;

  AdminProjectUserEditScreenBlocState(this.user);
}

class AdminProjectUserEditData {
  /// Optional for creation
  final String? userId;
  late TkCmsEditedFsUserAccess user;

  AdminProjectUserEditData({required this.userId});
}

class AdminProjectUserEditScreenBloc
    extends AutoDisposeStateBaseBloc<AdminProjectUserEditScreenBlocState> {
  /// Null for creation

  final AdminProjectUserEditScreenParam param;

  late final projectId = adminProjectFixProjectId(param.projectId);
  //late StreamSubscription _studiesSubscription;

  AdminProjectUserEditScreenBloc({required this.param}) {
    () async {
      if (!disposed) {
        var userId = param.userId;
        if (userId == null) {
          add(AdminProjectUserEditScreenBlocState(null));
        } else {
          var fsDb = globalFestenaoFirestoreDatabase.projectDb;
          var userAccessRef = fsDb
              .fsEntityUserAccessRef(projectId, userId)
              .cast<TkCmsEditedFsUserAccess>();
          var userAccess = await userAccessRef.get(fsDb.firestore);
          if (!disposed) {
            add(AdminProjectUserEditScreenBlocState(userAccess));
          }
        }
      }
    }();
  }

  Future<void> delete(String userId) async {
    var fsDb = globalFestenaoFirestoreDatabase.projectDb;
    await fsDb.leaveEntity(projectId, userId: userId);
  }

  Future<void> save(AdminProjectUserEditData data) async {
    var userId = data.userId ?? param.userId!;

    var fsDb = globalFestenaoFirestoreDatabase.projectDb;
    var userAccess = data.user;
    userAccess.fixAccess();

    await fsDb.setEntityUserAccess(
      entityId: projectId,
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

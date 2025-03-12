import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';

import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

class FsAppUserEditScreenParam {
  final String? appId; // Optional appId
  /// Null for creation
  final String? userId;
  FsAppUserEditScreenParam({required this.userId, this.appId});
}

class FsAppUserEditScreenBlocState {
  final TkCmsFsUserAccess? user;

  FsAppUserEditScreenBlocState(this.user);
}

class FsAppUserEditScreenBloc
    extends AutoDisposeStateBaseBloc<FsAppUserEditScreenBlocState> {
  /// Null for creation

  final FsAppUserEditScreenParam param;

  //late StreamSubscription _studiesSubscription;

  FsAppUserEditScreenBloc({required this.param}) {
    () async {
      if (!disposed) {
        var userId = param.userId;
        if (userId == null) {
          add(FsAppUserEditScreenBlocState(null));
        } else {
          var appId = _appId;
          var fsDb = globalFestenaoFirestoreDatabase.appDb;
          var userAccessRef = fsDb.fsEntityUserAccessRef(appId, userId);
          var userAccess = await userAccessRef.get(fsDb.firestore);
          if (!disposed) {
            add(FsAppUserEditScreenBlocState(userAccess));
          }
        }
      }
    }();
  }

  String get _appId => param.appId ?? globalFestenaoFirestoreDatabase.appId;
  Future<void> save(AdminUserEditData data) async {
    var userId = data.userId ?? param.userId!;

    var appId = _appId;
    var fsDb = globalFestenaoFirestoreDatabase.appDb;
    var userAccess = data.user;
    userAccess.fixAccess();

    await fsDb.setEntityUserAccess(
      entityId: appId,
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

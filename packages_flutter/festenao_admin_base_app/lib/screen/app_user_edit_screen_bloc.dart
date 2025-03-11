import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';

import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

class AppUserEditScreenParam {
  /// Null for creation
  final String? userId;
  AppUserEditScreenParam({required this.userId});
}

class AppUserEditScreenBlocState {
  final TkCmsFsUserAccess? user;

  AppUserEditScreenBlocState(this.user);
}

class AppUserEditScreenBloc
    extends AutoDisposeStateBaseBloc<AppUserEditScreenBlocState> {
  /// Null for creation

  final AppUserEditScreenParam param;

  //late StreamSubscription _studiesSubscription;

  AppUserEditScreenBloc({required this.param}) {
    () async {
      if (!disposed) {
        var userId = param.userId;
        if (userId == null) {
          add(AppUserEditScreenBlocState(null));
        } else {
          var app = globalFestenaoFirestoreDatabase.app;
          var fsDb = globalFestenaoFirestoreDatabase.appDb;
          var userAccessRef = fsDb.fsEntityUserAccessRef(app, userId);
          var userAccess = await userAccessRef.get(fsDb.firestore);
          if (!disposed) {
            add(
              AppUserEditScreenBlocState(
                userAccess,
              ),
            );
          }
        }
      }
    }();
  }

  Future<void> save(AdminUserEditData data) async {
    var userId = data.userId ?? param.userId!;

    var app = globalFestenaoFirestoreDatabase.app;
    var fsDb = globalFestenaoFirestoreDatabase.appDb;
    var userAccess = data.user;
    userAccess.fixAccess();

    await fsDb.setEntityUserAccess(
        entityId: app, userId: userId, userAccess: userAccess);
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

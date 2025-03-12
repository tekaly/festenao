import 'package:festenao_admin_base_app/firebase/firestore_database.dart';

import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

class AdminUserEditScreenParam {
  final String projectId;

  /// Null for creation
  final String? userId;
  AdminUserEditScreenParam({required this.userId, required this.projectId});
}

class AdminUserEditScreenBlocState {
  final TkCmsFsUserAccess? user;

  AdminUserEditScreenBlocState(this.user);
}

class AdminUserEditData {
  /// Optional for creation
  final String? userId;
  late TkCmsFsUserAccess user;

  AdminUserEditData({required this.userId});
}

class AdminUserEditScreenBloc
    extends AutoDisposeStateBaseBloc<AdminUserEditScreenBlocState> {
  /// Null for creation

  final AdminUserEditScreenParam param;

  //late StreamSubscription _studiesSubscription;

  AdminUserEditScreenBloc({required this.param}) {
    () async {
      if (!disposed) {
        var userId = param.userId;
        if (userId == null) {
          add(AdminUserEditScreenBlocState(null));
        } else {
          var fsDb = globalFestenaoFirestoreDatabase.projectDb;
          var userAccessRef = fsDb.fsEntityUserAccessRef(
            param.projectId,
            userId,
          );
          var userAccess = await userAccessRef.get(fsDb.firestore);
          if (!disposed) {
            add(AdminUserEditScreenBlocState(userAccess));
          }
        }
      }
    }();
  }

  Future<void> save(AdminUserEditData data) async {
    var userId = data.userId ?? param.userId!;

    var fsDb = globalFestenaoFirestoreDatabase.projectDb;
    var userAccess = data.user;
    userAccess.fixAccess();

    await fsDb.setEntityUserAccess(
      entityId: param.projectId,
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

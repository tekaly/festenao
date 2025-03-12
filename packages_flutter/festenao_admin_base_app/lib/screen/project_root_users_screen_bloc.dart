import 'dart:async';

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';

import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

class AdminUsersScreenParam {
  final String id;

  AdminUsersScreenParam({required this.id});
}

class AdminUsersScreenBlocState {
  AdminUsersScreenBlocState(this.users);

  final List<TkCmsFsUserAccess> users;
}

class AdminUsersScreenBloc
    extends AutoDisposeStateBaseBloc<AdminUsersScreenBlocState> {
  final AdminUsersScreenParam param;

  List<TkCmsFsUserAccess>? users;

  late StreamSubscription _usersSubscription;

  void trigger() {
    if (users != null) {
      add(AdminUsersScreenBlocState(users!));
    }
  }

  AdminUsersScreenBloc({required this.param}) {
    var fsDb = globalFestenaoFirestoreDatabase.projectDb;

    audiAddStreamSubscription(
      fsDb
          .fsEntityUserAccessCollectionRef(param.id)
          .onSnapshots(fsDb.firestore)
          .listen((list) async {
            users = list;
            trigger();
          }),
    );
  }

  @override
  void dispose() {
    _usersSubscription.cancel();
    super.dispose();
  }
}

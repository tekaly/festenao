import 'dart:async';

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/sembast/projects_db_bloc.dart';
import 'package:festenao_common/data/festenao_firestore.dart';

import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

class AdminProjectUsersScreenParam {
  final String id;

  AdminProjectUsersScreenParam({required this.id});
}

class AdminProjectUsersScreenBlocState {
  AdminProjectUsersScreenBlocState(this.users);

  final List<TkCmsEditedFsUserAccess> users;
}

/// Fix the project id (compat only)
String adminProjectFixProjectId(String projectId) {
  var dbBloc = globalProjectsDbBlocOrNull;
  if (dbBloc is SingleCompatProjectDbBloc) {
    projectId = dbBloc.projectId;
  }
  return projectId;
}

class AdminProjectUsersScreenBloc
    extends AutoDisposeStateBaseBloc<AdminProjectUsersScreenBlocState> {
  final AdminProjectUsersScreenParam param;

  List<TkCmsEditedFsUserAccess>? users;

  late StreamSubscription _usersSubscription;
  final _supportOptionsController = TrackChangesSupportOptionsController();

  void trigger() {
    if (users != null) {
      add(AdminProjectUsersScreenBlocState(users!));
    }
  }

  late final projectId = adminProjectFixProjectId(param.id);

  late final CvCollectionReference<TkCmsEditedFsUserAccess> usersRef;
  AdminProjectUsersScreenBloc({required this.param}) {
    var fsDb = globalFestenaoFirestoreDatabase.projectDb;

    var collectionRef = usersRef = fsDb
        .fsEntityUserAccessCollectionRef(projectId)
        .cast<TkCmsEditedFsUserAccess>();
    _usersSubscription = audiAddStreamSubscription(
      collectionRef
          .onSnapshotsSupport(
            fsDb.firestore,
            options: _supportOptionsController,
          )
          .listen((list) async {
            users = list;
            trigger();
          }),
    );
  }

  String get usersPath => usersRef.path;

  void refresh() {
    _supportOptionsController.trigger();
  }

  @override
  void dispose() {
    _usersSubscription.cancel();
    super.dispose();
  }
}

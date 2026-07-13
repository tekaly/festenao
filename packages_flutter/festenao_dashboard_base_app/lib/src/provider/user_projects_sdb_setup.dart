import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Global per user projects sdb manager, null when not installed.
UserProjectsSdbManager? globalFestenaoUserProjectsSdbManagerOrNull;

/// Install per user projects database handling.
///
/// [globalProjectsSdbOrNull] then follows the identity: when a user is
/// authenticated it becomes a per user database synced to firestore
/// `app/<app>/user_prv/<userId>/data/projects` (locally sandboxed to the user
/// id), otherwise a plain local database.
UserProjectsSdbManager initFestenaoUserProjectsSdbManager({
  required SdbFactory factory,
  required Firestore firestore,
  required String app,
  String? name,
  TkCmsFbIdentityBloc? identityBloc,
}) {
  var manager = UserProjectsSdbManager(
    factory: factory,
    firestore: firestore,
    app: app,
    name: name,
  );
  globalFestenaoUserProjectsSdbManagerOrNull = manager;
  identityBloc ??= globalTkCmsFbIdentityBloc;
  identityBloc.state.listen((state) {
    manager.setCurrentUser(state.identity?.userId);
  });
  return manager;
}

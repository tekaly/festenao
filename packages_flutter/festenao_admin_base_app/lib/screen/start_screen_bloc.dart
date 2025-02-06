import 'package:festenao_admin_base_app/auth/auth_bloc.dart';
import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:tekartik_firebase_auth_local/auth_local.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

class StartScreenBlocState {
  final FirebaseUser? user;

  /// Projects
  final List<DbProject>? projects;

  StartScreenBlocState({required this.user, required this.projects});
}

class StartScreenBloc extends AutoDisposeStateBaseBloc<StartScreenBlocState> {
  final _lock = Lock();
  // ignore: cancel_subscriptions
  StreamSubscription? _dbSubscription;
  String? _dbUserId;
  StartScreenBloc() {
    () async {
      audiAddStreamSubscription(globalAuthBloc.state.listen((state) {
        _lock.synchronized(() async {
          var user = state.user;
          var userId = user?.uid;
          if (userId != null && userId != _dbUserId) {
            _dbUserId = userId;
            audiDispose(_dbSubscription);
            add(StartScreenBlocState(projects: null, user: user));
            _dbSubscription = audiAddStreamSubscription(
                globalProjectsDb.onProjects(userId: userId).listen((projects) {
              add(StartScreenBlocState(projects: projects, user: user));
            }));
          } else {
            _dbUserId = null;
            if (userId == null) {
              add(StartScreenBlocState(user: null, projects: null));
            }
          }
        });
      }));
    }();
  }
}

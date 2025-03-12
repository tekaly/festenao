import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_auth.dart';

class StartScreenBlocState {
  final TkCmsFbIdentity? identity;

  /// Projects (for user only)
  final List<DbProject>? projects;

  StartScreenBlocState({required this.identity, required this.projects});
}

class StartScreenBloc extends AutoDisposeStateBaseBloc<StartScreenBlocState> {
  final _lock = Lock();
  // ignore: cancel_subscriptions
  StreamSubscription? _dbSubscription;
  String? _dbUserId;
  StartScreenBloc() {
    () async {
      audiAddStreamSubscription(
        globalTkCmsFbIdentityBloc.state.listen((state) {
          _lock.synchronized(() async {
            var identity = state.identity;
            if (identity is TkCmsFbIdentityUser) {
              var user = identity.user;
              var userId = user.uid;
              if (userId != _dbUserId) {
                _dbUserId = userId;
                audiDispose(_dbSubscription);

                /// Show identification first, if db projects are not synchronized yet
                add(StartScreenBlocState(projects: null, identity: identity));
                _dbSubscription = audiAddStreamSubscription(
                  globalProjectsDb.onProjects(userId: userId).listen((
                    projects,
                  ) {
                    add(
                      StartScreenBlocState(
                        projects: projects,
                        identity: identity,
                      ),
                    );
                  }),
                );
              }
            } else {
              _dbUserId = null;

              add(StartScreenBlocState(identity: identity, projects: null));
            }
          });
        }),
      );
    }();
  }
}

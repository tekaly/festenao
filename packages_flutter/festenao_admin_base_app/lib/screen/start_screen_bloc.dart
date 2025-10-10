import 'package:festenao_admin_base_app/admin_app/admin_app_project_context.dart';
import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:festenao_admin_base_app/sembast/projects_db_bloc.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

class StartScreenBlocState {
  final TkCmsFbIdentity? identity;

  /// Enforced project id if any
  final String? enforcedProjectId;

  /// Projects (for user only)
  final List<DbProject>? projects;

  StartScreenBlocState({
    required this.identity,
    required this.projects,
    this.enforcedProjectId,
  });

  @override
  String toString() => 'identity $identity ${enforcedProjectId ?? projects}';
}

class StartScreenBloc extends AutoDisposeStateBaseBloc<StartScreenBlocState> {
  final _lock = Lock();
  // ignore: cancel_subscriptions
  StreamSubscription? _dbSubscription;

  String? _dbIdentityId;
  StartScreenBloc() {
    () async {
      audiAddStreamSubscription(
        globalTkCmsFbIdentityBloc.state.listen((state) {
          _lock.synchronized(() async {
            var identity = state.identity;
            if (identity != null) {
              var identityId = identity.userOrAccountId!;

              if (identityId != _dbIdentityId) {
                _dbIdentityId = identityId;

                if (globalProjectsDbBloc is EnforcedSingleProjectDbBloc) {
                  var dbBloc =
                      globalProjectsDbBloc as EnforcedSingleProjectDbBloc;
                  var projectId = dbBloc.enforcedProjectId;
                  add(
                    StartScreenBlocState(
                      projects: null,
                      enforcedProjectId: projectId,
                      identity: identity,
                    ),
                  );
                  return;
                }
                audiDispose(_dbSubscription);

                /// Show identification first, if db projects are not synchronized yet
                add(StartScreenBlocState(projects: null, identity: identity));
                _dbSubscription = audiAddStreamSubscription(
                  globalProjectsDb.onProjects(userId: identityId).listen((
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
            } else if (identity is TkCmsFbIdentityServiceAccount) {
              audiDispose(_dbSubscription);

              /// Show identification first, if db projects are not synchronized yet
              add(
                StartScreenBlocState(
                  projects: [
                    DbProject()
                      ..name.v = 'Built-in project'
                      ..uid.v = ByProjectIdAdminAppProjectContext.mainProjectId,
                  ],
                  identity: identity,
                ),
              );
              /*
              _dbSubscription = audiAddStreamSubscription(
                globalProjectsDb
                    .onProjects(
                      userId: TkCmsFbIdentityServiceAccount.userLocalId,
                    )
                    .listen((projects) {
                      add(
                        StartScreenBlocState(
                          projects: projects,
                          identity: identity,
                        ),
                      );
                    }),
              );*/
            } else {
              _dbIdentityId = null;

              add(StartScreenBlocState(identity: identity, projects: null));
            }
          });
        }),
      );
    }();
  }
}

import 'package:festenao_admin_base_app/admin_app/admin_app_project_context.dart';
import 'package:festenao_admin_base_app/auth/auth_bloc.dart';
import 'package:festenao_admin_base_app/sembast/projects_db_bloc.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_base_bloc.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';

/// Short life context per screen
class AdminAppProjectContextDbBloc implements AutoDisposable {
  final FestenaoAdminAppProjectContext projectContext;

  AdminAppProjectContextDbBloc({required this.projectContext});

  ByProjectIdAdminAppProjectContext get byIdProjectContext =>
      (projectContext as ByProjectIdAdminAppProjectContext);

  String get _projectId => byIdProjectContext.projectId;
  GrabbedContentDb? _grabbedContentDb;

  final _lock = Lock();

  Future<Database> grabDatabase() async {
    return await (await grabSyncedDb()).database;
  }

  MultiProjectsDbBloc get multiProjectsDbBloc =>
      globalProjectsDbBloc as MultiProjectsDbBloc;
  Future<SyncedDb> grabSyncedDb() async {
    if (projectContext is SingleFestenaoAdminAppProjectContext) {
      return (projectContext as SingleFestenaoAdminAppProjectContext).syncedDb;
    } else if (projectContext is ByProjectIdAdminAppProjectContext) {
      var projectsDbBloc = globalProjectsDbBloc;
      if (projectsDbBloc is MultiProjectsDbBloc) {
        return (await _grabContentDb()).contentDb.syncedDb;
      } else if (projectsDbBloc is SingleProjectDbBloc) {
        return projectsDbBloc.syncedDb;
      } else {
        throw StateError('Invalid projectsDbBloc $projectsDbBloc');
      }
    } else {
      throw ArgumentError('Invalid project context $projectContext');
    }
  }

  /// To call once
  Future<GrabbedContentDb> _grabContentDb() async {
    _grabbedContentDb ??= await () async {
      return _lock.synchronized(() async {
        return _grabbedContentDb ??= await () async {
          var userId =
              globalAuthBloc.state.value.user?.uid ?? 'service_account';
          return await multiProjectsDbBloc.grabContentDb(
            userId: userId,
            projectId: _projectId,
          );
        }();
      });
    }();
    return _grabbedContentDb!;
  }

  @override
  void audiDispose() {
    var projectsDbBloc = globalProjectsDbBloc;
    if (projectsDbBloc is MultiProjectsDbBloc) {
      var grabbedContextDb = _grabbedContentDb;
      if (grabbedContextDb != null) {
        _lock.synchronized(() async {
          await projectsDbBloc.releaseContentDb(grabbedContextDb);
        });
      }
    }
  }
}

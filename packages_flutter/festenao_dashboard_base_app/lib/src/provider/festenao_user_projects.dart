import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_dashboard_base_app/festenao_dashboard_base_app.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'festenao_user_projects.g.dart';

/// Users projects, the current (possibly per user) database.
@Riverpod(keepAlive: true)
UserProjectsSdb rpdUserProjectsDb(Ref ref) {
  // Dependency
  ref.watch(festenaoUserProjectsSdbManagerProvider);
  var manager = globalFestenaoUserProjectsSdbManagerOrNull;
  if (manager != null) {
    var db = manager.currentDb;
    // Rebuild when the per user database changes.
    var subscription = manager.onCurrentDb.listen((newDb) {
      if (!identical(newDb, db)) {
        ref.invalidateSelf();
      }
    });
    ref.onDispose(subscription.cancel);
    if (db != null) {
      return db;
    }
  }
  return globalProjectsSdbOrNull ?? UserProjectsSdb.inMemory();
}

/// User projects
@riverpod
Stream<List<SdbUserProject>> rpdUserProjects(Ref ref, String userId) {
  var projectsDb = ref.watch(rpdUserProjectsDbProvider);
  return projectsDb.onProjects(userId: userId);
}

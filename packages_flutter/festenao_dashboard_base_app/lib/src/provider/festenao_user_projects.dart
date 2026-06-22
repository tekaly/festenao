import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'festenao_user_projects.g.dart';

/// Users projects
@Riverpod(keepAlive: true)
UserProjectsSdb rpdUserProjectsDb(Ref ref) {
  return UserProjectsSdb.inMemory();
}

/// User projects
@riverpod
Stream<List<SdbUserProject>> rpdUserProjects(Ref ref, String userId) {
  var projectsDb = ref.watch(rpdUserProjectsDbProvider);
  return projectsDb.onProjects(userId: userId);
}

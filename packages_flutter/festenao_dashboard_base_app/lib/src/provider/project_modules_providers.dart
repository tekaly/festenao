/// The modules on in a project, from its local mirror (`SdbUserProject`).
library;

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/festenao_modules.dart';
import 'package:festenao_dashboard_base_app/src/provider/festenao_user_projects.dart';
import 'package:festenao_dashboard_base_app/src/provider/project_access_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tkcms_common/tkcms_auth.dart';

part 'project_modules_providers.g.dart';

/// The module of the blog screens.
const dashboardModuleBlog = 'blog';

/// The module of the content screens (artists, locations, events, images,
/// medias).
const dashboardModuleContent = 'content';

/// The module of the quizz screens.
const dashboardModuleQuizz = 'quizz';

/// The modules on in the project [projectId] for the signed in user, from
/// the local projects database: null when every module is on, or while the
/// project is not known yet (so nothing is hidden by mistake).
@riverpod
Stream<List<String>?> projectModules(Ref ref, String projectId) {
  var userId = ref.watch(rpdIdentityProvider)?.userOrAccountId;
  if (userId == null) {
    return Stream.value(null);
  }
  var projectsSdb = ref.watch(rpdUserProjectsDbProvider);
  return projectsSdb
      .onProject(projectId, userId: userId)
      .map((project) => project?.modules.v);
}

/// Sets the modules on in the project [projectId] (every module when
/// [modules] is null) and its local mirror for the signed in user, so
/// [projectModulesProvider] follows right away. The project admins can.
Future<void> dashboardSetProjectModules(
  WidgetRef ref,
  String projectId,
  List<String>? modules,
) async {
  var userId = ref.read(rpdIdentityProvider)?.userOrAccountId;
  if (userId == null) {
    throw StateError('not signed in');
  }
  await globalFestenaoFirestoreDatabase.setProjectModulesAndMirror(
    projectId,
    modules,
    projectsSdb: ref.read(rpdUserProjectsDbProvider),
    userId: userId,
  );
}

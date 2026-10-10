/// Self-serve project creation, for an app whose users create their own
/// projects (a festival, a playlist...).
library;

import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/festenao_slug.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_dashboard_base_app/src/provider/festenao_user_projects.dart';
import 'package:festenao_dashboard_base_app/src/provider/project_access_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tkcms_common/tkcms_auth.dart';

/// Creates the project [name] for the signed in user, its admin, with its
/// [modules] (every module when null) and its url [slug] (`/p/<slug>`) when
/// given, and adds it to the local projects of the user; returns its id.
///
/// Throws [FestenaoSlugTakenException] before creating anything when [slug]
/// is taken (checked first; when another project takes it in between, the
/// project is created without its url and the exception is thrown).
Future<String> dashboardCreateProject(
  WidgetRef ref, {
  required String name,
  String? slug,
  List<String>? modules,
}) async {
  var userId = ref.read(rpdIdentityProvider)?.userOrAccountId;
  if (userId == null) {
    throw StateError('not signed in');
  }
  var fsDb = globalFestenaoFirestoreDatabase;
  if (slug != null && slug.isNotEmpty) {
    if (await fsDb.slugRegistry().resolve(slug) != null) {
      throw FestenaoSlugTakenException(slug);
    }
  }
  var fsProject = FsProject()..name.v = name;
  if (modules != null) {
    fsProject.modules.v = modules;
  }
  var projectId = await fsDb.projectDb.createEntity(
    userId: userId,
    entity: fsProject,
  );
  var synchronizer = UserProjectsSdbSynchronizer(
    projectsSdb: ref.read(rpdUserProjectsDbProvider),
    fsProjects: fsDb.projectDb,
  );
  try {
    await synchronizer.syncOne(userId: userId, projectId: projectId);
  } finally {
    synchronizer.dispose();
  }
  if (slug != null && slug.isNotEmpty) {
    await fsDb.setProjectSlug(projectId, slug);
  }
  return projectId;
}

import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_slug.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tkcms_common/tkcms_auth.dart';

import 'project_access_providers.dart';

/// The current slug of the entity [entityId] of the scoped entity access
/// ([currentEntityAccessProvider]), live; null when it has none, or when the
/// entity is not a project (only the projects have an url, `/p/<slug>`).
///
/// Read from the entity document (its `slug` copy, see
/// [FestenaoFirestoreDatabaseSlugExt.setProjectSlug]) whatever its model.
final dashboardEntitySlugProvider = StreamProvider.autoDispose
    .family<String?, String>((ref, entityId) {
      var fsDb = ref.watch(currentEntityAccessProvider);
      if (fsDb.entityCollectionInfo.id != festenaoProjectSlugEntityType) {
        return Stream.value(null);
      }
      return fsDb.firestore
          .doc(fsDb.fsEntityRef(entityId).path)
          .onSnapshotSupport()
          .map(
            (snapshot) =>
                snapshot.exists ? snapshot.data['slug'] as String? : null,
          );
    }, name: 'dashboardEntitySlug');

/// True when the entity access scoped by [currentEntityAccessProvider] is the
/// festenao projects one: its entities have an url (`/p/<slug or id>`).
final dashboardEntityHasUrlProvider = Provider.autoDispose<bool>(
  (ref) =>
      ref.watch(currentEntityAccessProvider).entityCollectionInfo.id ==
      festenaoProjectSlugEntityType,
  name: 'dashboardEntityHasUrl',
);

/// Every slug of the project [projectId] of the global festenao database,
/// the current one first ([FsProjectSlugExt.urlSlugs]), live; empty when it
/// has none.
final dashboardProjectUrlSlugsProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, projectId) {
      var fsDb = globalFestenaoFirestoreDatabase;
      return fsDb.projectDb
          .fsEntityRef(projectId)
          .onSnapshotSupport(fsDb.firestore)
          .map((project) => project.urlSlugs);
    }, name: 'dashboardProjectUrlSlugs');

/// The app access of the signed in user ([FestenaoFirestoreDatabaseSlugRightsExt.onAppUserAccess]),
/// live; null signed out. A service account is a super admin.
final dashboardAppUserAccessProvider =
    StreamProvider.autoDispose<TkCmsFsUserAccess?>((ref) {
      var identity = ref.watch(rpdIdentityProvider);
      if (identity == null) {
        return Stream.value(null);
      }
      if (identity.isServiceAccount) {
        return Stream.value(TkCmsFsUserAccess.superAdmin());
      }
      return globalFestenaoFirestoreDatabase.onAppUserAccess(
        identity.userOrAccountId,
      );
    }, name: 'dashboardAppUserAccess');

/// True when the signed in user chooses the project urls: an app admin or a
/// holder of the app [festenaoSlugRole] (the rules built with the app right
/// allow nobody else); everyone else shares the project id.
final dashboardCanSetSlugProvider = Provider.autoDispose<bool>((ref) {
  var identity = ref.watch(rpdIdentityProvider);
  if (identity?.isServiceAccount ?? false) {
    return true;
  }
  return ref.watch(dashboardAppUserAccessProvider).value?.canSetSlug ?? false;
}, name: 'dashboardCanSetSlug');

/// True when the signed in user is an admin of the app: it sees every url in
/// use ([dashboardAppSlugsProvider]).
final dashboardIsAppAdminProvider = Provider.autoDispose<bool>((ref) {
  var identity = ref.watch(rpdIdentityProvider);
  if (identity?.isServiceAccount ?? false) {
    return true;
  }
  var access = ref.watch(dashboardAppUserAccessProvider).value;
  return access != null && access.exists && access.isAdmin;
}, name: 'dashboardIsAppAdmin');

/// Every slug of the app (the app admins only, as the rules allow), sorted.
final dashboardAppSlugsProvider =
    FutureProvider.autoDispose<List<FsFestenaoSlug>>(
      (ref) => globalFestenaoFirestoreDatabase.slugRegistry().list(),
      name: 'dashboardAppSlugs',
    );

/// The name of the project [projectId], null when it cannot be read (not a
/// member, deleted).
final dashboardProjectNameProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, projectId) async {
      var fsDb = globalFestenaoFirestoreDatabase;
      try {
        var project = await fsDb.projectDb
            .fsEntityRef(projectId)
            .get(fsDb.firestore);
        return project.exists ? project.name.v : null;
      } catch (_) {
        return null;
      }
    }, name: 'dashboardProjectName');

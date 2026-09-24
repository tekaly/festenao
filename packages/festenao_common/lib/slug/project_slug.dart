/// The slugs of the festenao projects: `https://<hosting>/p/<slug>` opens a
/// project, whoever may read it (a public project: anyone).
///
/// The registry is the one of the app (`app/<app>/slug/<slug>`), the entity
/// type `project` (its collection, whose admin access the slug rules check,
/// see `festenao_firebase` `addSlugRules`); the project document keeps a
/// copy of its current slug ([FsProject.slug]).
library;

import 'package:festenao_common/data/src/model/fs_paths.dart'
    show projectPathPart;
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:tkcms_common/tkcms_firestore_v2.dart';

import 'slug.dart';
import 'slug_registry.dart';

/// The entity type of a project in the slug registry.
const festenaoProjectSlugEntityType = projectPathPart;

/// The first segment of a project url (`/p/<slug>`).
const festenaoProjectUrlPathSegment = 'p';

/// Slugs of the projects of a festenao database.
extension FestenaoFirestoreDatabaseSlugExt on FestenaoFirestoreDatabase {
  /// The slug registry of the app.
  FestenaoSlugRegistry slugRegistry({
    FestenaoSlugOptions options = festenaoSlugOptionsDefault,
  }) => FestenaoSlugRegistry(
    firestore: firestore,
    rootPath: fsAppRoot(app).path,
    options: options,
  );

  /// Give the project [projectId] the url [slug] (an admin of the project,
  /// or the server), the previous one becoming an alias: its links keep
  /// working. One transaction for the registry and the project document.
  ///
  /// Throws [FestenaoSlugTakenException] when another entity has it,
  /// [FestenaoSlugInvalidException] when not valid.
  Future<void> setProjectSlug(
    String projectId,
    String slug, {
    FestenaoSlugOptions options = festenaoSlugOptionsDefault,
  }) async {
    var registry = slugRegistry(options: options);
    var ref = projectDb.fsEntityRef(projectId);
    await firestore.cvRunTransaction((txn) async {
      var project = await txn.refGet(ref);
      if (!project.exists) {
        throw StateError('Project $projectId not found');
      }
      await registry.txnClaim(
        txn,
        slug: slug,
        entityType: festenaoProjectSlugEntityType,
        entityId: projectId,
        previousSlug: project.slug.v,
      );
      txn.refSet(ref, FsProject()..slug.v = slug, SetOptions(merge: true));
    });
  }

  /// The project id of [slug] (following an alias), null when it is not a
  /// project slug.
  Future<String?> resolveProjectSlug(
    String slug, {
    FestenaoSlugOptions options = festenaoSlugOptionsDefault,
  }) async {
    var doc = await slugRegistry(options: options).resolve(slug);
    if (doc == null || doc.entityType.v != festenaoProjectSlugEntityType) {
      return null;
    }
    return doc.entityId.v;
  }

  /// Release the current slug of [projectId] (the project is being
  /// deleted). Its aliases stay (a client cannot list them) and resolve to
  /// a project that no longer exists.
  Future<void> releaseProjectSlug(String projectId) async {
    var project = await projectDb.fsEntityRef(projectId).get(firestore);
    var slug = project.slug.v;
    if (slug != null) {
      await slugRegistry().release(
        slug,
        entityType: festenaoProjectSlugEntityType,
        entityId: projectId,
      );
    }
  }
}

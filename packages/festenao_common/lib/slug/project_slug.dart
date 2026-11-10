/// The slugs of the festenao projects: `https://<hosting>/p/<slug>` opens a
/// project, whoever may read it (a public project: anyone).
///
/// The registry is the one of the app (`app/<app>/slug/<slug>`), the entity
/// type `project` (its collection, whose admin access the slug rules check,
/// see `festenao_firebase` `addSlugRules`); the project document keeps a
/// copy of its current slug ([FsProject.slug]) and of all of them
/// ([FsProject.slugs]).
///
/// A project has one current slug, its canonical url, and may have more
/// (`/p/tradhiv` and `/p/tradhiv2027`): they all open it, the app showing
/// the current one. A project without a slug opens at `/p/<projectId>`
/// ([resolveProjectUrlSegment]).
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

/// What a project id may look like in a url (`/p/<projectId>`).
final _projectIdRegExp = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// The url slugs of a project document.
extension FsProjectSlugExt on FsProject {
  /// Every slug of the project url, the current one first (see
  /// [FsProject.slugs]).
  List<String> get urlSlugs => {?slug.v, ...?slugs.v}.toList();

  /// The url segment of the project (`/p/<segment>`): its current slug, or
  /// its id.
  String get urlSegment => slug.v ?? id;
}

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

  Future<FsProject> _txnGetProject(
    CvFirestoreTransaction txn,
    String projectId,
  ) async {
    var project = await txn.refGet(projectDb.fsEntityRef(projectId));
    if (!project.exists) {
      throw StateError('Project $projectId not found');
    }
    return project;
  }

  void _txnSetProjectSlugs(
    CvFirestoreTransaction txn,
    String projectId, {
    required String? slug,
    required List<String> slugs,
  }) {
    txn.refSet(
      projectDb.fsEntityRef(projectId),
      FsProject()
        ..slug.v = slug
        ..slugs.v = slugs.isEmpty ? null : slugs,
      SetOptions(merge: true),
    );
  }

  /// Give the project [projectId] the url [slug] (an admin of the project,
  /// or the server), the previous one becoming an alias: its links keep
  /// working. One transaction for the registry and the project document.
  ///
  /// [slug] may already be one of the project slugs: it becomes the current
  /// one.
  ///
  /// Throws [FestenaoSlugTakenException] when another entity has it,
  /// [FestenaoSlugInvalidException] when not valid.
  Future<void> setProjectSlug(
    String projectId,
    String slug, {
    FestenaoSlugOptions options = festenaoSlugOptionsDefault,
  }) async {
    var registry = slugRegistry(options: options);
    await firestore.cvRunTransaction((txn) async {
      var project = await _txnGetProject(txn, projectId);
      await registry.txnClaim(
        txn,
        slug: slug,
        entityType: festenaoProjectSlugEntityType,
        entityId: projectId,
        previousSlug: project.slug.v,
      );
      _txnSetProjectSlugs(
        txn,
        projectId,
        slug: slug,
        slugs: [slug, ...project.urlSlugs.where((other) => other != slug)],
      );
    });
  }

  /// Give the project [projectId] the extra url [slug], its current one
  /// unchanged (the current one when it has none).
  ///
  /// Throws [FestenaoSlugTakenException] when another entity has it,
  /// [FestenaoSlugInvalidException] when not valid.
  Future<void> addProjectSlug(
    String projectId,
    String slug, {
    FestenaoSlugOptions options = festenaoSlugOptionsDefault,
  }) async {
    var registry = slugRegistry(options: options);
    await firestore.cvRunTransaction((txn) async {
      var project = await _txnGetProject(txn, projectId);
      var current = project.slug.v;
      await registry.txnClaim(
        txn,
        slug: slug,
        entityType: festenaoProjectSlugEntityType,
        entityId: projectId,
        alias: current != null && current != slug,
      );
      _txnSetProjectSlugs(
        txn,
        projectId,
        slug: current ?? slug,
        slugs: {...project.urlSlugs, slug}.toList(),
      );
    });
  }

  /// Give the url [slug] to the project [projectId], taking it from the
  /// project that has it (the next edition of a festival, a copy made to
  /// try something): one transaction for the registry and both project
  /// documents, the url opens one project or the other, never nothing.
  ///
  /// [slug] becomes the current slug of [projectId], its previous one an
  /// alias (as [setProjectSlug]). The project it is taken from falls back
  /// to the next of its slugs, or to its id. The same as [setProjectSlug]
  /// when no other project has it.
  ///
  /// Throws [FestenaoSlugTakenException] when an entity that is not a
  /// project has it, [FestenaoSlugInvalidException] when not valid.
  Future<void> moveProjectSlug(
    String slug,
    String projectId, {
    FestenaoSlugOptions options = festenaoSlugOptionsDefault,
  }) async {
    var registry = slugRegistry(options: options);
    var error = options.check(slug);
    if (error != null) {
      throw FestenaoSlugInvalidException(slug, error);
    }
    await firestore.cvRunTransaction((txn) async {
      // Every read before the first write.
      var target = await _txnGetProject(txn, projectId);
      var existing = await txn.refGet(registry.ref(slug));
      FsProject? source;
      FsFestenaoSlug? sourceNext;
      var sourceRemaining = <String>[];
      if (existing.exists &&
          !existing.isEntity(festenaoProjectSlugEntityType, projectId)) {
        var sourceId = existing.entityId.v;
        if (existing.entityType.v != festenaoProjectSlugEntityType ||
            sourceId == null) {
          throw FestenaoSlugTakenException(slug);
        }
        // A project deleted since: its slug is simply taken over.
        var project = await txn.refGet(projectDb.fsEntityRef(sourceId));
        if (project.exists) {
          source = project;
          sourceRemaining = project.urlSlugs
              .where((other) => other != slug)
              .toList();
          if (project.slug.v == slug && sourceRemaining.isNotEmpty) {
            var next = await txn.refGet(registry.ref(sourceRemaining.first));
            if (next.exists &&
                next.isEntity(festenaoProjectSlugEntityType, sourceId)) {
              sourceNext = next;
            }
          }
        }
      }
      var previousSlug = target.slug.v;
      FsFestenaoSlug? previous;
      if (previousSlug != null && previousSlug != slug) {
        previous = await txn.refGet(registry.ref(previousSlug));
      }

      var now = Timestamp.now();
      txn.refSet(
        registry.ref(slug),
        FsFestenaoSlug()
          ..entityType.v = festenaoProjectSlugEntityType
          ..entityId.v = projectId
          ..alias.v = false
          ..created.v = existing.exists ? existing.created.v ?? now : now
          ..updated.v = now,
      );
      if (previous != null &&
          previous.exists &&
          previous.isEntity(festenaoProjectSlugEntityType, projectId)) {
        txn.refSet(
          registry.ref(previousSlug!),
          FsFestenaoSlug()
            ..copyFrom(previous)
            ..alias.v = true
            ..updated.v = now,
        );
      }
      _txnSetProjectSlugs(
        txn,
        projectId,
        slug: slug,
        slugs: [slug, ...target.urlSlugs.where((other) => other != slug)],
      );
      if (source != null) {
        if (sourceNext != null) {
          txn.refSet(
            registry.ref(sourceNext.slug),
            FsFestenaoSlug()
              ..copyFrom(sourceNext)
              ..alias.v = false
              ..updated.v = now,
          );
        }
        _txnSetProjectSlugs(
          txn,
          source.id,
          slug: source.slug.v == slug ? sourceNext?.slug : source.slug.v,
          slugs: sourceRemaining,
        );
      }
    });
  }

  /// Release the url [slug] of the project [projectId]. When it was the
  /// current one, the next of [FsProject.slugs] takes its place.
  Future<void> removeProjectSlug(
    String projectId,
    String slug, {
    FestenaoSlugOptions options = festenaoSlugOptionsDefault,
  }) async {
    var registry = slugRegistry(options: options);
    await firestore.cvRunTransaction((txn) async {
      var project = await _txnGetProject(txn, projectId);
      bool isProject(FsFestenaoSlug doc) =>
          doc.exists && doc.isEntity(festenaoProjectSlugEntityType, projectId);

      // Every read before the first write.
      var existing = options.isValid(slug)
          ? await txn.refGet(registry.ref(slug))
          : null;
      var remaining = project.urlSlugs.where((other) => other != slug).toList();
      var current = project.slug.v;
      FsFestenaoSlug? next;
      if (current == slug && remaining.isNotEmpty) {
        next = await txn.refGet(registry.ref(remaining.first));
        if (!isProject(next)) {
          next = null;
        }
      }

      if (existing != null && isProject(existing)) {
        txn.refDelete(registry.ref(slug));
      }
      if (next != null) {
        txn.refSet(
          registry.ref(next.slug),
          FsFestenaoSlug()
            ..copyFrom(next)
            ..alias.v = false
            ..updated.v = Timestamp.now(),
        );
      }
      _txnSetProjectSlugs(
        txn,
        projectId,
        slug: current == slug ? next?.slug : current,
        slugs: remaining,
      );
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

  /// The project id of the url `/p/<segment>`: the project of the slug
  /// [segment] (any case), else [segment] itself when it is the id of a
  /// project (the url of a project without a slug). Null when neither.
  ///
  /// A project the user cannot read (private, signed out) still resolves to
  /// its id: its own screen tells why it does not open.
  Future<String?> resolveProjectUrlSegment(
    String segment, {
    FestenaoSlugOptions options = festenaoSlugOptionsDefault,
  }) async {
    var projectId = await resolveProjectSlug(
      segment.toLowerCase(),
      options: options,
    );
    if (projectId != null) {
      return projectId;
    }
    if (!_projectIdRegExp.hasMatch(segment)) {
      return null;
    }
    try {
      var project = await projectDb.fsEntityRef(segment).get(firestore);
      return project.exists ? segment : null;
    } catch (_) {
      return segment;
    }
  }

  /// Release the slugs of [projectId] (the project is being deleted): its
  /// current one and the others of [FsProject.slugs]. The older aliases
  /// missing from it stay (a client cannot list them) and resolve to a
  /// project that no longer exists.
  Future<void> releaseProjectSlug(String projectId) async {
    var project = await projectDb.fsEntityRef(projectId).get(firestore);
    var registry = slugRegistry();
    for (var slug in project.urlSlugs) {
      await registry.release(
        slug,
        entityType: festenaoProjectSlugEntityType,
        entityId: projectId,
      );
    }
  }
}

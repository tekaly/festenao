/// The firestore slug registry: what makes a slug unique and resolves it to
/// its entity.
///
/// One document per slug, under a root document (the app, typically):
///
/// ```
/// app/<app>/slug/<slug>        FsFestenaoSlug {entityType, entityId, alias}
/// ```
///
/// Resolving a link is one `get` (the rules let anyone get a slug document,
/// never list them). Claiming one is a transaction: the document is created
/// only if it does not exist or already points to the same entity, so two
/// entities never share a slug. When an entity moves to a new slug its old
/// one stays as an [FsFestenaoSlug.alias], so the links already shared keep
/// working (and nobody else can take it over).
///
/// Written by the api function of an app (admin firestore), or by the entity
/// admins themselves in an app with no backend, as the rules allow.
library;

import 'package:tkcms_common/tkcms_firestore_v2.dart';

import 'slug.dart';

/// The collection of the slug documents, under the root document.
const festenaoSlugCollectionId = 'slug';

/// A slug document: the entity a slug points to.
class FsFestenaoSlug extends CvFirestoreDocumentBase {
  /// The entity type (`project`, `event`...).
  final entityType = CvField<String>('entityType');

  /// The entity id.
  final entityId = CvField<String>('entityId');

  /// True once the entity moved to another slug: this one still resolves,
  /// the app redirects to the current one.
  final alias = CvField<bool>('alias');

  /// Creation time.
  final created = CvField<Timestamp>('created');

  /// Last update time.
  final updated = CvField<Timestamp>('updated');

  @override
  CvFields get fields => [entityType, entityId, alias, created, updated];

  /// The slug (the document id).
  String get slug => id;

  /// True when it points to [entityType] [entityId].
  bool isEntity(String entityType, String entityId) =>
      this.entityType.v == entityType && this.entityId.v == entityId;
}

var _buildersInitialized = false;

/// Register the slug registry builders.
void initFestenaoSlugBuilders() {
  if (_buildersInitialized) {
    return;
  }
  _buildersInitialized = true;
  cvAddConstructors([FsFestenaoSlug.new]);
}

/// A slug that is not valid.
class FestenaoSlugInvalidException implements Exception {
  /// The slug.
  final String slug;

  /// Why.
  final FestenaoSlugError error;

  /// A slug that is not valid.
  FestenaoSlugInvalidException(this.slug, this.error);

  @override
  String toString() => 'FestenaoSlugInvalidException($slug, ${error.name})';
}

/// A slug taken by another entity.
class FestenaoSlugTakenException implements Exception {
  /// The slug.
  final String slug;

  /// A slug taken by another entity.
  FestenaoSlugTakenException(this.slug);

  @override
  String toString() => 'FestenaoSlugTakenException($slug)';
}

/// The slugs of the entities below [rootPath] (`app/<app>`).
class FestenaoSlugRegistry {
  /// The firestore (admin on the server, the user's one on a client).
  final Firestore firestore;

  /// The root document path, `app/<app>` typically.
  final String rootPath;

  /// The slug rules.
  final FestenaoSlugOptions options;

  /// The slugs of the entities below [rootPath].
  FestenaoSlugRegistry({
    required this.firestore,
    required this.rootPath,
    this.options = festenaoSlugOptionsDefault,
  }) {
    initFestenaoSlugBuilders();
  }

  /// The slug collection.
  CvCollectionReference<FsFestenaoSlug> get collection =>
      CvCollectionReference<FsFestenaoSlug>(
        '$rootPath/$festenaoSlugCollectionId',
      );

  /// The document of [slug].
  CvDocumentReference<FsFestenaoSlug> ref(String slug) => collection.doc(slug);

  void _checkValid(String slug) {
    var error = options.check(slug);
    if (error != null) {
      throw FestenaoSlugInvalidException(slug, error);
    }
  }

  /// What [slug] points to, null when nothing (or not a valid slug).
  Future<FsFestenaoSlug?> resolve(String slug) async {
    if (!options.isValid(slug)) {
      return null;
    }
    var doc = await ref(slug).get(firestore);
    return doc.exists ? doc : null;
  }

  /// True when [slug] is valid and free, or already points to [entityType]
  /// [entityId] (when given).
  Future<bool> isAvailable(
    String slug, {
    String? entityType,
    String? entityId,
  }) async {
    if (!options.isValid(slug)) {
      return false;
    }
    var doc = await resolve(slug);
    if (doc == null) {
      return true;
    }
    return entityType != null &&
        entityId != null &&
        doc.isEntity(entityType, entityId);
  }

  /// Point [slug] to [entityType] [entityId], in [txn].
  ///
  /// Throws [FestenaoSlugTakenException] when it points to another entity,
  /// [FestenaoSlugInvalidException] when not valid. [previousSlug], the
  /// current slug of the entity, becomes an alias when [keepAlias] (its
  /// links keep working), or is released. Every read happens before the
  /// first write, as firestore transactions require.
  Future<void> txnClaim(
    CvFirestoreTransaction txn, {
    required String slug,
    required String entityType,
    required String entityId,
    String? previousSlug,
    bool keepAlias = true,
  }) async {
    _checkValid(slug);
    var existing = await txn.refGet(ref(slug));
    if (existing.exists && !existing.isEntity(entityType, entityId)) {
      throw FestenaoSlugTakenException(slug);
    }
    FsFestenaoSlug? previous;
    if (previousSlug != null && previousSlug != slug) {
      previous = await txn.refGet(ref(previousSlug));
    }
    var now = Timestamp.now();
    txn.refSet(
      ref(slug),
      FsFestenaoSlug()
        ..entityType.v = entityType
        ..entityId.v = entityId
        ..alias.v = false
        ..created.v = existing.exists ? existing.created.v ?? now : now
        ..updated.v = now,
    );
    if (previous != null &&
        previous.exists &&
        previous.isEntity(entityType, entityId)) {
      if (keepAlias) {
        txn.refSet(
          ref(previousSlug!),
          FsFestenaoSlug()
            ..copyFrom(previous)
            ..alias.v = true
            ..updated.v = now,
        );
      } else {
        txn.refDelete(ref(previousSlug!));
      }
    }
  }

  /// Point [slug] to [entityType] [entityId], see [txnClaim].
  Future<void> claim({
    required String slug,
    required String entityType,
    required String entityId,
    String? previousSlug,
    bool keepAlias = true,
  }) => firestore.cvRunTransaction(
    (txn) => txnClaim(
      txn,
      slug: slug,
      entityType: entityType,
      entityId: entityId,
      previousSlug: previousSlug,
      keepAlias: keepAlias,
    ),
  );

  /// Claim the first free slug derived from [text] (a name, see
  /// [FestenaoSlugOptions.candidates]) and return it.
  ///
  /// Throws [FestenaoSlugTakenException] when every candidate is taken.
  Future<String> claimFromText(
    String text, {
    required String entityType,
    required String entityId,
    String fallback = 'x',
    int count = 20,
  }) async {
    var base = options.slugify(text, fallback: fallback);
    String? last;
    for (var candidate in options.candidates(base, count: count)) {
      last = candidate;
      try {
        await claim(
          slug: candidate,
          entityType: entityType,
          entityId: entityId,
        );
        return candidate;
      } on FestenaoSlugTakenException {
        continue;
      }
    }
    throw FestenaoSlugTakenException(last ?? base);
  }

  /// Every slug of [entityType] [entityId], aliases included (a query: the
  /// server, or an admin firestore).
  Future<List<FsFestenaoSlug>> slugsOf(
    String entityType,
    String entityId,
  ) async {
    var list = await collection
        .query()
        .where(FsFestenaoSlug().entityId.name, isEqualTo: entityId)
        .get(firestore);
    return list.where((doc) => doc.entityType.v == entityType).toList();
  }

  /// Release [slug] if it points to [entityType] [entityId].
  Future<void> release(
    String slug, {
    required String entityType,
    required String entityId,
  }) => firestore.cvRunTransaction((txn) async {
    if (!options.isValid(slug)) {
      return;
    }
    var existing = await txn.refGet(ref(slug));
    if (existing.exists && existing.isEntity(entityType, entityId)) {
      txn.refDelete(ref(slug));
    }
  });

  /// Release every slug of [entityType] [entityId] (the entity is deleted);
  /// see [slugsOf].
  Future<void> releaseAll(String entityType, String entityId) async {
    for (var doc in await slugsOf(entityType, entityId)) {
      await ref(doc.slug).delete(firestore);
    }
  }
}

/// Slugs: the configurable, human readable part of an entity url
/// (`https://<hosting>/p/<slug>`), their rules ([FestenaoSlugOptions],
/// [festenaoSlugify]), the firestore registry making them unique and
/// resolving them to their entity ([FestenaoSlugRegistry]), the slugs of
/// the festenao projects ([FestenaoFirestoreDatabaseSlugExt]) and who may
/// choose one when an app keeps it to a few users ([festenaoSlugRole]).
///
/// Pure Dart; the slug editing field is in `festenao_common_flutter`
/// (`festenao_slug_flutter.dart`).
library;

export 'slug/project_slug.dart';
export 'slug/slug.dart';
export 'slug/slug_registry.dart';
export 'slug/slug_rights.dart';

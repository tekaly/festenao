import 'package:festenao_common/data/festenao_db.dart';

/// Known artist types (extend as needed).
const artistTypes = <String>[];

/// Tags specific to artist articles.
const artistTags = <String>[];

/// Artist record stored as a string-keyed record in the Sembast database.
///
/// Inherits common CMS fields via [DbArticleMixin]. Every artist has:
/// - A display name ([name])
/// - An optional custom type ([type])
/// - Markdown biography or details ([content])
/// - Social/Web links ([attributes])
/// - Visual references ([image], [thumbnail], [squareImage])
///
/// ### Example Usage
///
/// #### Instantiating and Writing:
/// ```dart
/// var artist = DbArtist()
///   ..id = 'daft-punk'
///   ..name.v = 'Daft Punk'
///   ..content.v = 'Electronic music duo from Paris, France.'
///   ..tags.v = ['headliner'];
///
/// // Write to Sembast database (FestenaoDb)
/// await dbArtistStoreRef.record(artist.id).put(db, artist);
/// ```
///
/// #### Querying Artists:
/// ```dart
/// // Fetch all artists
/// List<DbArtist> artists = await dbArtistStoreRef.query().getRecords(db);
///
/// // Find a specific artist by ID
/// DbArtist? artist = await dbArtistStoreRef.record('daft-punk').get(db);
/// ```
class DbArtist extends DbStringRecordBase with DbArticleMixin {
  @override
  List<CvField> get fields => [...articleFields];

  @override
  String get articleKind => articleKindArtist;
}

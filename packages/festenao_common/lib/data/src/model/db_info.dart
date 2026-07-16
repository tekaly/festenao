import 'package:festenao_common/data/festenao_db.dart';

/// Known info types used for generic info articles.
const infoTypes = [infoTypeLocation, infoTypeSong, infoTypePlaylist];

/// Tags used for info articles (extendable).
const infoTags = <String>[];

/// Info type for locations.
const infoTypeLocation = 'location';

/// Info type for songs (temporary until more types added).
const infoTypeSong = 'song';

/// Info type for playlists.
const infoTypePlaylist = 'playlist';

/// Generic info page/record stored as a string-keyed record.
///
/// Used for unstructured pages, lyrics of a song, or custom playlists.
///
/// ### Example Usage
///
/// #### Instantiating and Writing:
/// ```dart
/// var infoPage = DbInfo()
///   ..id = 'info-general-rules'
///   ..name.v = 'Festival Rules'
///   ..type.v = infoTypeLocation
///   ..content.v = '1. No outside food...\n2. Respect others...';
///
/// // Write to Sembast database (FestenaoDb)
/// await dbInfoStoreRef.record(infoPage.id).put(db, infoPage);
/// ```
///
/// #### Querying Info Pages:
/// ```dart
/// // Fetch all info pages
/// List<DbInfo> infoPages = await dbInfoStoreRef.query().getRecords(db);
///
/// // Retrieve specific info page by ID
/// DbInfo? info = await dbInfoRecordRef('info-general-rules').get(db);
/// ```
class DbInfo extends DbStringRecordBase with DbArticleMixin {
  @override
  List<CvField> get fields => [...articleFields];

  @override
  String get articleKind => articleKindInfo;
}

/// Default model instance for info records.
var dbInfoModel = DbInfo();

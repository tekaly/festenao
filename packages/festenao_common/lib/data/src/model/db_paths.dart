import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:tekaly_sembast_synced/synced_db_internals.dart';

/// Sembast store reference for [DbImage] records, identified by a `String` key.
///
/// Store Name: `'image'`.
///
/// #### Querying Example:
/// ```dart
/// List<DbImage> images = await dbImageStoreRef.query().getRecords(db);
/// ```
var dbImageStoreRef = cvStringStoreFactory.store<DbImage>('image');

/// Sembast store reference for [DbArtist] records, identified by a `String` key.
///
/// Store Name: `'artist'`.
///
/// #### Querying Example:
/// ```dart
/// List<DbArtist> artists = await dbArtistStoreRef.query().getRecords(db);
/// ```
var dbArtistStoreRef = cvStringStoreFactory.store<DbArtist>('artist');

/// Sembast store reference for [DbFestenaoMediaFile] records, identified by a `String` key.
///
/// Store Name: `'media'`.
///
/// Represents media file records that are synchronized between local and Firestore.
var dbMediaStoreRef = cvStringStoreFactory.store<DbFestenaoMediaFile>('media');

/// Sembast store reference for local [DbFestenaoMediaFileStatus] records.
///
/// Store Name: `'media_status_local'`.
///
/// Excluded from sync by default. Tracks download/upload status on this device.
var dbMediaLocalStoreRef = cvStringStoreFactory
    .store<DbFestenaoMediaFileStatus>('media_status_local');

/// Sembast store reference for [DbEvent] records, identified by a `String` key.
///
/// Store Name: `'event'`.
///
/// #### Querying Example:
/// ```dart
/// List<DbEvent> events = await dbEventStoreRef.query().getRecords(db);
/// ```
var dbEventStoreRef = cvStringStoreFactory.store<DbEvent>('event');

/// Sembast store reference for internal [DbSyncRecord] records, identified by an `int` key.
///
/// Store Name: `'faoR'`.
///
/// Used internally by the offline sync mechanism to track local changes.
var dbSyncRecordStoreRef = cvIntStoreFactory.store<DbSyncRecord>('faoR');

/// Sembast store reference for sync meta-information [DbSyncMetaInfo], identified by a `String` key.
///
/// Store Name: `'faoM'`.
///
/// Stores internal sync states (timestamps, last sync change ids, etc.).
var dbSyncMetaStoreRef = cvStringStoreFactory.store<DbSyncMetaInfo>('faoM');

/// Sembast store reference for generic [DbMeta] records.
///
/// Store Name: `'meta'`.
var dbMetaStoreRef = cvStringStoreFactory.store<DbMeta>('meta');

/// Specific record reference for the global metadata record ('general').
///
/// Points to key `'general'` inside [dbMetaStoreRef] and cast as [DbMetaGeneral].
var dbMetaGeneralRecordRef = dbMetaStoreRef
    .record('general')
    .castV<DbMetaGeneral>();

var _metaRefs = [dbMetaGeneralRecordRef];
var _refMap = _metaRefs.asMap().map(
  (index, value) => MapEntry(_metaRefs[index].key, value),
);

/// Returns the [CvRecordRef] for the given meta [key], or null if none.
CvRecordRef<String, DbMeta>? refForMeta(String key) => _refMap[key];
// Compat

/// Sembast store reference for [DbInfo] records, identified by a `String` key.
///
/// Store Name: `'info'`.
///
/// #### Querying Example:
/// ```dart
/// List<DbInfo> infoPages = await dbInfoStoreRef.query().getRecords(db);
/// ```
final dbInfoStoreRef = cvStringStoreFactory.store<DbInfo>('info');

/// Helper function to retrieve a specific typed record reference for a [DbInfo] document by its [id].
CvRecordRef<String, DbInfo> dbInfoRecordRef(String id) =>
    dbInfoStoreRef.record(id);

/// Deprecated alias for [dbImageStoreRef].
@Deprecated('use dbImageStoreRef')
var imageStore = dbImageStoreRef;

/// Deprecated alias for [dbArtistStoreRef].
@Deprecated('use dbArtistStore')
var artistStore = dbArtistStoreRef;

/// Deprecated alias for [dbEventStoreRef].
@Deprecated('use dbEventStoreRef')
var eventStore = dbEventStoreRef;

/// Deprecated alias for [dbSyncRecordStoreRef].
@Deprecated('use dbSyncRecordStoreRef')
var syncRecordStore = dbSyncRecordStoreRef;

/// Deprecated alias for [dbSyncMetaStoreRef].
@Deprecated('use dbSyncMetaStoreRef')
var syncMetaStore = dbSyncMetaStoreRef;

/// Deprecated alias for [dbInfoStoreRef].
@Deprecated('use dbInfoStoreRef')
var infoStore = dbInfoStoreRef;

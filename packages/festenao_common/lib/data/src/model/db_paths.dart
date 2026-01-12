import 'package:festenao_common/data/festenao_db.dart';
import 'package:tekaly_sembast_synced/synced_db_internals.dart';

/// Store reference for image records.
var dbImageStoreRef = cvStringStoreFactory.store<DbImage>('image');

/// Store reference for artist records.
var dbArtistStoreRef = cvStringStoreFactory.store<DbArtist>('artist');

/// Store reference for event records.
var dbEventStoreRef = cvStringStoreFactory.store<DbEvent>('event');

/// Store reference for sync record entries.
var dbSyncRecordStoreRef = cvIntStoreFactory.store<DbSyncRecord>('faoR');

/// Store reference for sync metadata.
var dbSyncMetaStoreRef = cvStringStoreFactory.store<DbSyncMetaInfo>('faoM');

/// Store reference for generic meta records.
var dbMetaStoreRef = cvStringStoreFactory.store<DbMeta>('meta');

/// Record ref for the general meta document.
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

/// Store reference for info records.
final dbInfoStoreRef = cvStringStoreFactory.store<DbInfo>('info');

/// Helper to get a typed record ref for an info document by [id].
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

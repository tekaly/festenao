import 'package:festenao_common/data/festenao_db.dart';
import 'package:tekaly_sembast_synced/synced_db_internals.dart';

var dbImageStoreRef = cvStringStoreFactory.store<DbImage>('image');
var dbArtistStoreRef = cvStringStoreFactory.store<DbArtist>('artist');
var dbEventStoreRef = cvStringStoreFactory.store<DbEvent>('event');

var dbSyncRecordStoreRef = cvIntStoreFactory.store<DbSyncRecord>('faoR');
var dbSyncMetaStoreRef = cvStringStoreFactory.store<DbSyncMetaInfo>('faoM');

var dbMetaStoreRef = cvStringStoreFactory.store<DbMeta>('meta');
var dbMetaGeneralRecordRef =
    dbMetaStoreRef.record('general').castV<DbMetaGeneral>();

var _metaRefs = [dbMetaGeneralRecordRef];
var _refMap = _metaRefs.asMap().map(
  (index, value) => MapEntry(_metaRefs[index].key, value),
);
CvRecordRef<String, DbMeta>? refForMeta(String key) => _refMap[key];
// Compat

final dbInfoStoreRef = cvStringStoreFactory.store<DbInfo>('info');

CvRecordRef<String, DbInfo> dbInfoRecordRef(String id) =>
    dbInfoStoreRef.record(id);
@Deprecated('use dbImageStoreRef')
var imageStore = dbImageStoreRef;
@Deprecated('use dbArtistStore')
var artistStore = dbArtistStoreRef;
@Deprecated('use dbEventStoreRef')
var eventStore = dbEventStoreRef;
@Deprecated('use dbSyncRecordStoreRef')
var syncRecordStore = dbSyncRecordStoreRef;
@Deprecated('use dbSyncMetaStoreRef')
var syncMetaStore = dbSyncMetaStoreRef;
@Deprecated('use dbInfoStoreRef')
var infoStore = dbInfoStoreRef;

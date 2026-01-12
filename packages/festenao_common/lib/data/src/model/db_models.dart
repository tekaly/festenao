import 'package:festenao_common/data/festenao_db.dart';
import 'package:tekaly_sembast_synced/synced_db_internals.dart';

var _initFestenaoDbBuildersDone = false;
var _initFestenaoUserDbBuildersDone = false;

/// Initialize Festenao database builders.
void initFestenaoDbBuilders() {
  if (!_initFestenaoDbBuildersDone) {
    _initFestenaoDbBuildersDone = true;
    cvAddConstructor(DbArtist.new);
    cvAddConstructor(DbImage.new);
    cvAddConstructor(DbEvent.new);
    cvAddConstructor(DbImage.new);
    cvAddConstructor(DbInfo.new);
    cvAddConstructor(DbLocation.new);
    cvAddConstructor(DbMeta.new);
    cvAddConstructor(DbMetaGeneral.new);
    cvAddConstructor(DbSyncRecord.new);
    cvAddConstructor(CvAttribute.new);
    cvAddConstructor(DbRecordMap.new);
    cvAddConstructor(DbSyncMetaInfo.new);
    cvAddConstructor(CvSyncedSourceRecordData.new);
    /*
    cvAddBuilder<DbMeta>((map) {
      refForMeta(map)
    });*/
  }
}

/// Initialize Festenao user database builders.
void initFestenaoUserDbBuilders() {
  if (!_initFestenaoUserDbBuildersDone) {
    _initFestenaoUserDbBuildersDone = true;
    cvAddConstructor(DbFavorite.new);
  }
}

import 'package:festenao_common/data/festenao_db.dart';

const infoTypes = [infoTypeLocation, infoTypeSong, infoTypePlaylist];
const infoTags = <String>[];
const infoTypeLocation = 'location';
// Temp until we get a type
const infoTypeSong = 'song';
const infoTypePlaylist = 'playlist';

/// Info id decided by the app
class DbInfo extends DbStringRecordBase with DbArticleMixin {
  @override
  List<CvField> get fields => [
        ...articleFields,
      ];

  @override
  String get articleKind => articleKindInfo;
}

/// Model
var dbInfoModel = DbInfo();

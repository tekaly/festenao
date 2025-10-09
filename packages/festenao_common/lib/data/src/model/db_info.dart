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

/// Generic info record stored as a string-keyed record.
class DbInfo extends DbStringRecordBase with DbArticleMixin {
  @override
  List<CvField> get fields => [...articleFields];

  @override
  String get articleKind => articleKindInfo;
}

/// Default model instance for info records.
var dbInfoModel = DbInfo();

import 'package:festenao_common/data/festenao_db.dart';

/// Known artist types (extend as needed).
const artistTypes = <String>[];

/// Tags specific to artist articles.
const artistTags = <String>[];

/// Artist record stored as a string-keyed record.
///
/// Inherits common article fields via [DbArticleMixin] and sets the article kind.
class DbArtist extends DbStringRecordBase with DbArticleMixin {
  @override
  List<CvField> get fields => [...articleFields];

  @override
  String get articleKind => articleKindArtist;
}

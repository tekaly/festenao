import 'package:festenao_common/data/festenao_db.dart';

const artistTypes = <String>[];
const artistTags = <String>[];

/// Artist id must allow sorting (i.e. typically lastname_firstname
class DbArtist extends DbStringRecordBase with DbArticleMixin {
  @override
  List<CvField> get fields => [...articleFields];

  @override
  String get articleKind => articleKindArtist;
}

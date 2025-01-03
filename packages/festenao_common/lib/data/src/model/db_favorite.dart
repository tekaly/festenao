import 'package:festenao_common/data/festenao_db.dart';

/// Key is the event id, in the local festenao db
class DbFavorite extends DbStringRecordBase {
  final isFavorite = CvField<bool>('isFavorite');

  @override
  List<CvField> get fields => [isFavorite];
}

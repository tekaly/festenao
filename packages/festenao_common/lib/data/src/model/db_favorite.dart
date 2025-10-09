import 'package:festenao_common/data/festenao_db.dart';

/// Favorite flag stored per-event in the local festenao DB.
///
/// The record key is the event id in the local database.
class DbFavorite extends DbStringRecordBase {
  /// Whether the item is marked as favorite.
  final isFavorite = CvField<bool>('isFavorite');

  @override
  List<CvField> get fields => [isFavorite];
}

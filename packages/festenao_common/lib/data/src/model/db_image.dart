import 'package:festenao_common/data/festenao_db.dart';

/// Image in the database.
class DbImage extends DbStringRecordBase {
  // The actual file name (typically .jpg or .png)
  final name = CvField<String>('name');
  final blurHash = CvField<String>('blurHash');
  final width = CvField<int>('width');
  final height = CvField<int>('height');

  double get aspectRatio => (width.v ?? 1) / (height.v ?? 1);

  /// Copyright information
  final copyright = CvField<String>('copyright');

  @override
  List<CvField> get fields => [name, copyright, blurHash, width, height];
}

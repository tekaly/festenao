import 'package:festenao_common/data/festenao_db.dart';

/// Represents an image stored in the database.
class DbImage extends DbStringRecordBase {
  /// The actual file name (typically with extension like .jpg or .png).
  final name = CvField<String>('name');

  /// BlurHash for lightweight previews.
  final blurHash = CvField<String>('blurHash');

  /// Image width in pixels.
  final width = CvField<int>('width');

  /// Image height in pixels.
  final height = CvField<int>('height');

  /// Calculated aspect ratio (width / height).
  double get aspectRatio => (width.v ?? 1) / (height.v ?? 1);

  /// Copyright information for the image.
  final copyright = CvField<String>('copyright');

  @override
  List<CvField> get fields => [name, copyright, blurHash, width, height];
}

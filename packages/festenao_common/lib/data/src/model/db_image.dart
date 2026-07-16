import 'package:festenao_common/data/festenao_db.dart';

/// Represents an image metadata record stored in the database.
///
/// Images are referenced from articles (like [DbArtist] or [DbEvent]) by their
/// record ID (the string key). The record itself holds metadata such as sizes,
/// aspect ratio, credits, and BlurHash.
///
/// ### Fields
/// - [name]: The file name including its extension (e.g. `daft_punk.jpg`).
/// - [blurHash]: A compact, base83 string encoding of a blurry image placeholder (useful for progressive loading).
/// - [width]: The pixel width of the source image.
/// - [height]: The pixel height of the source image.
/// - [copyright]: Photographer, designer, or copyright owner name/credits.
///
/// ### Example Usage
///
/// #### Instantiating and Writing:
/// ```dart
/// var image = DbImage()
///   ..id = 'img_john_doe_hero'
///   ..name.v = 'john_doe_hero.jpg'
///   ..width.v = 1920
///   ..height.v = 1080
///   ..blurHash.v = 'LEHV6nWB2yk8x]t7RjRj00oI_3j['
///   ..copyright.v = 'Jane Photographer';
///
/// // Write to Sembast database (FestenaoDb)
/// await dbImageStoreRef.record(image.id).put(db, image);
/// ```
///
/// #### Querying Images:
/// ```dart
/// // Fetch all image records
/// List<DbImage> images = await dbImageStoreRef.query().getRecords(db);
///
/// // Retrieve specific image record by ID
/// DbImage? image = await dbImageStoreRef.record('img_john_doe_hero').get(db);
/// ```
class DbImage extends DbStringRecordBase {
  /// The actual file name (typically with extension like `.jpg` or `.png`).
  final name = CvField<String>('name');

  /// BlurHash string representation for lightweight placeholders.
  final blurHash = CvField<String>('blurHash');

  /// Image width in pixels.
  final width = CvField<int>('width');

  /// Image height in pixels.
  final height = CvField<int>('height');

  /// Calculated aspect ratio (`width` / `height`). Falls back to `1.0` if dimensions are missing.
  double get aspectRatio => (width.v ?? 1) / (height.v ?? 1);

  /// Copyright or credit attribution text.
  final copyright = CvField<String>('copyright');

  @override
  List<CvField> get fields => [name, copyright, blurHash, width, height];
}

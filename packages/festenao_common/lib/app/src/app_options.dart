import '../../data/festenao_db.dart';

/// The default width for main images in pixels.
const imageWidthDefault = 800;

/// The default size for square images in pixels.
const squareSizeDefault = 320;

/// The default size for grid images in pixels.
const gridSizeDefault = 480;

/// The default width for thumbnail images in pixels.
const thumbnailWidthDefault = 64;

/// Image options for the Festenao app.
///
/// Includes type, width, and height fields for image configuration.
class FestenaoAppImageOptions extends CvModelBase {
  /// The image type (e.g., thumbnail, main, square, grid).
  final type = CvField<String>('type');

  /// The image width in pixels.
  final width = CvField<int>('width');

  /// The image height in pixels.
  final height = CvField<int>('height');

  @override
  List<CvField> get fields => [type, width, height];

  @override
  String toString() => '${type.v} ${width.v}x${height.v}';
}

/// Default image options for thumbnails.
final thumbnailAppImageOptions = FestenaoAppImageOptions()
  ..width.v = thumbnailWidthDefault
  ..height.v = thumbnailWidthDefault
  ..type.v = imageTypeThumbnail;

/// Default image options for main images.
final mainAppImageOptions = FestenaoAppImageOptions()
  ..width.v = imageWidthDefault
  ..type.v = imageTypeMain;

/// Default image options for square images.
final squareAppImageOptions = FestenaoAppImageOptions()
  ..width.v = squareSizeDefault
  ..height.v = squareSizeDefault
  ..type.v = imageTypeSquare;

/// Default image options for grid images.
final gridAppImageOptions = FestenaoAppImageOptions()
  ..width.v = gridSizeDefault
  ..height.v = gridSizeDefault
  ..type.v = imageTypeGrid;

/// App-wide options for Festenao.
class FestenaoAppDataOptions extends CvModelBase {
  /// List of image options for the app.
  final images = CvModelListField<FestenaoAppImageOptions>(
    'images',
    (_) => FestenaoAppImageOptions(),
  );

  @override
  List<CvField> get fields => [images];
}

/// Extension for [FestenaoAppDataOptions] to retrieve image options by type.
extension FestenaoAppOptionsExt on FestenaoAppDataOptions {
  /// Returns the [FestenaoAppImageOptions] for the given [type], or null if not found.
  FestenaoAppImageOptions? getOptionsByType(String type) {
    if (images.v != null) {
      for (var image in images.v!) {
        if (image.type.v == type) {
          return image;
        }
      }
    }
    return null;
  }
}

/// The default app options for Festenao.
var festenaoAppOptionsDefault = FestenaoAppDataOptions()
  ..images.v = [
    thumbnailAppImageOptions,
    mainAppImageOptions,
    squareAppImageOptions,
    gridAppImageOptions,
  ];

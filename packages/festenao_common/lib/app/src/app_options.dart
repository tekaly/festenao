import '../../data/festenao_db.dart';

const imageWidthDefault = 800;
const squareSizeDefault = 320;
const gridSizeDefault = 480;
const thumbnailWidthDefault = 64;

class FestenaoAppImageOptions extends CvModelBase {
  final type = CvField<String>('type');
  final width = CvField<int>('width');
  final height = CvField<int>('height');

  @override
  List<CvField> get fields => [type, width, height];

  @override
  String toString() => '${type.v} ${width.v}x${height.v}';
}

final thumbnailAppImageOptions = FestenaoAppImageOptions()
  ..width.v = thumbnailWidthDefault
  ..height.v = thumbnailWidthDefault
  ..type.v = imageTypeThumbnail;
final mainAppImageOptions = FestenaoAppImageOptions()
  ..width.v = imageWidthDefault
  ..type.v = imageTypeMain;

final squareAppImageOptions = FestenaoAppImageOptions()
  ..width.v = squareSizeDefault
  ..height.v = squareSizeDefault
  ..type.v = imageTypeSquare;

final gridAppImageOptions = FestenaoAppImageOptions()
  ..width.v = gridSizeDefault
  ..height.v = gridSizeDefault
  ..type.v = imageTypeGrid;

class FestenaoAppOptions extends CvModelBase {
  final images = CvModelListField<FestenaoAppImageOptions>(
    'images',
    (_) => FestenaoAppImageOptions(),
  );

  @override
  List<CvField> get fields => [images];
}

extension FestenaoAppOptionsExt on FestenaoAppOptions {
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

var festenaoAppOptionsDefault = FestenaoAppOptions()
  ..images.v = [
    thumbnailAppImageOptions,
    mainAppImageOptions,
    squareAppImageOptions,
    gridAppImageOptions,
  ];

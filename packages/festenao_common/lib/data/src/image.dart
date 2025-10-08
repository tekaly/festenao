import 'package:festenao_common/data/festenao_sdk.dart';

/// Builds a stable image id for an article based on SDK version.
///
/// For SDK v2+ the format is `<articleKind>_<articleId>_<imageType>`.
/// For older SDK versions the format is `<articleKind>_<imageType>_<articleId>`.
String articleKindToImageId(
  String articleKind,
  String imageType,
  String articleId,
) {
  if (festenaoSdkVersion >= festenaoSdkVersionV2) {
    return '${articleKind}_${articleId}_$imageType';
  } else {
    return '${articleKind}_${imageType}_$articleId';
  }
}

/// Image type constant for thumbnails.
const imageTypeThumbnail = 'thumb';

/// Image type constant for main images.
const imageTypeMain = 'main';

/// Image type constant for grid-sized images.
const imageTypeGrid = 'grid';

/// Image type constant for square images.
const imageTypeSquare = 'square';

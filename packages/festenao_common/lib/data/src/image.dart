import 'package:festenao_common/data/festenao_sdk.dart';

/// Default id for image such
/// artist_thumb_my_artist
String articleKindToImageId(
    String articleKind, String imageType, String articleId) {
  if (festenaoSdkVersion >= festenaoSdkVersionV2) {
    return '${articleKind}_${articleId}_$imageType';
  } else {
    return '${articleKind}_${imageType}_$articleId';
  }
}

const imageTypeThumbnail = 'thumb';
const imageTypeMain = 'main';
const imageTypeGrid = 'grid';
const imageTypeSquare = 'square';

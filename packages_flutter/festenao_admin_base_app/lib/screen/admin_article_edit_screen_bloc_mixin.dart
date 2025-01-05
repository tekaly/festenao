import 'dart:typed_data';

import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/sembast/booklets_db.dart';
import 'package:festenao_blur_hash/blur_hash.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:tekartik_common_utils/string_utils.dart';

class AdminArticleEditData {
  final DbArticle article;
  Uint8List? imageData;
  Uint8List? thumbailData;

  AdminArticleEditData(
      {required this.article, this.imageData, this.thumbailData});
}

mixin AdminArticleEditScreenBlocMixin<T extends DbArticle> {
  final db = globalBookletsDb.db;
  CvStoreRef<String, T> get articleStore;

  Future<void> save(AdminArticleEditData data) async {
    DbImage? dbImage;

    var imageData = data.imageData;
    var thumbnailImageData = data.thumbailData;
    var article = data.article;
    if (imageData != null) {
      var articleId = article.id;
      var imageId =
          stringNonEmpty(article.image.v) ?? '${articleStore.name}_$articleId';
      var image = img.decodeImage(imageData)!;
      var imageName = '$imageId.jpg';
      var blurHash = await image.blurHashEncode();
      dbImage = dbImageStoreRef.record(imageId).cv()
        ..name.v = imageName
        ..width.v = image.width
        ..height.v = image.height
        ..blurHash.v = blurHash;

      var path =
          globalFestenaoFirebaseContext.getImageDirStoragePath(imageName);
      await globalFirebaseContext.storage
          .bucket()
          .file(path)
          .writeAsBytes(Uint8List.fromList(img.encodeJpg(image, quality: 50)));
      await dbImage.put(db);

      // set in article
      article.image.v = imageId;
    }
    if (thumbnailImageData != null) {
      var articleId = article.id;
      var imageId = stringNonEmpty(article.thumbnail.v) ??
          '${articleStore.name}_thumb_$articleId';
      var image = img.decodeImage(thumbnailImageData)!;
      var imageName = '$imageId.jpg';
      var blurHash = await image.blurHashEncode();
      dbImage = dbImageStoreRef.record(imageId).cv()
        ..name.v = imageName
        ..width.v = image.width
        ..height.v = image.height
        ..blurHash.v = blurHash;

      var path = url.join(
          globalFestenaoFirebaseContext.storageRootPath, 'image', imageName);
      await globalFirebaseContext.storage
          .bucket()
          .file(path)
          .writeAsBytes(Uint8List.fromList(img.encodeJpg(image, quality: 50)));
      await dbImage.put(db);

      // set in article
      article.thumbnail.v = imageId;
    }

    await data.article.put(db);
  }
}

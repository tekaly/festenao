import 'dart:typed_data';

import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_blur_hash/blur_hash.dart';
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

abstract class AdminArticleEditScreenBloc {
  AdminAppProjectContextDbBloc get dbBloc;
}

mixin AdminArticleEditScreenBlocMixin<T extends DbArticle>
    implements AdminArticleEditScreenBloc {
  CvStoreRef<String, T> get articleStore;

  Future<void> save(AdminArticleEditData data) async {
    DbImage? dbImage;

    var imageData = data.imageData;
    var thumbnailImageData = data.thumbailData;
    var article = data.article;
    var db = await dbBloc.grabDatabase();
    var bucket = dbBloc.projectContext.storageBucket;
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
          globalFestenaoAppFirebaseContext.getImageDirStoragePath(imageName);
      await globalFestenaoAdminAppFirebaseContext.storage
          .bucket(bucket)
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
          globalFestenaoAppFirebaseContext.storageRootPath, 'image', imageName);
      await globalFestenaoAdminAppFirebaseContext.storage
          .bucket(bucket)
          .file(path)
          .writeAsBytes(Uint8List.fromList(img.encodeJpg(image, quality: 50)));
      await dbImage.put(db);

      // set in article
      article.thumbnail.v = imageId;
    }

    await data.article.put(db);
  }
}

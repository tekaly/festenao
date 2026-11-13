import 'dart:typed_data';

import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_blur_hash/blur_hash.dart';
import 'package:image/image.dart' as img;

class AdminArticleEditData {
  final DbArticle article;
  Uint8List? imageData;
  Uint8List? thumbailData;

  /// True for a new article: the save is refused when its id already exists.
  final bool create;

  AdminArticleEditData({
    required this.article,
    this.imageData,
    this.thumbailData,
    this.create = false,
  });
}

/// Thrown by a save creating an article whose id already exists.
class AdminArticleIdExistsException implements Exception {
  /// Store name.
  final String store;

  /// Article id.
  final String id;

  AdminArticleIdExistsException({required this.store, required this.id});

  @override
  String toString() => '$store $id already exists';
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
    if (data.create && await articleStore.record(article.id).exists(db)) {
      throw AdminArticleIdExistsException(
        store: articleStore.name,
        id: article.id,
      );
    }
    var bucket = dbBloc.projectContext.storageBucket;
    // A new image or thumbnail is the article's own (an id derived from the
    // article id), never the image the article points to: a duplicated
    // article points to the image of its source.
    if (imageData != null) {
      var articleId = article.id;
      var imageId = '${articleStore.name}_$articleId';
      var image = img.decodeImage(imageData)!;
      var imageName = '$imageId.jpg';
      var blurHash = await image.blurHashEncode();
      dbImage = dbImageStoreRef.record(imageId).cv()
        ..name.v = imageName
        ..width.v = image.width
        ..height.v = image.height
        ..blurHash.v = blurHash;

      var path = globalFestenaoAppFirebaseContext.getImageDirStoragePath(
        imageName,
      );
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
      var imageId = '${articleStore.name}_thumb_$articleId';
      var image = img.decodeImage(thumbnailImageData)!;
      var imageName = '$imageId.jpg';
      var blurHash = await image.blurHashEncode();
      dbImage = dbImageStoreRef.record(imageId).cv()
        ..name.v = imageName
        ..width.v = image.width
        ..height.v = image.height
        ..blurHash.v = blurHash;

      var path = globalFestenaoAppFirebaseContext.getImageDirStoragePath(
        imageName,
      );
      await globalFestenaoAdminAppFirebaseContext.storage
          .bucket(bucket)
          .file(path)
          .writeAsBytes(Uint8List.fromList(img.encodeJpg(image, quality: 50)));
      await dbImage.put(db);

      // set in article
      article.thumbnail.v = imageId;
    }

    // Merged: the fields not edited by the screen (sort, squareImage,
    // location, artists...) are kept.
    await data.article.put(db, merge: true);
  }
}

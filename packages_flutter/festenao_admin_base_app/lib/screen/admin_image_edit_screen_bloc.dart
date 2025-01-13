import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_blur_hash/blur_hash.dart';
import 'package:festenao_common/app/app_options.dart';
import 'package:flutter/foundation.dart';

import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:tekartik_common_utils/string_utils.dart';

import 'admin_image_edit_screen.dart';
// ignore: depend_on_referenced_packages

class AdminImageEditScreenBlocState {
  final String? imageId;

  /// Initial data if imageId is null
  final DbImage? image;

  AdminImageEditScreenBlocState({required this.imageId, this.image});
}

class AdminImageEditScreenParam {
  /// Template
  final DbImage? image;

  /// Only for creationg
  final FestenaoAppImageOptions? options;

  /// For new image only
  final String? newImageId;

  AdminImageEditScreenParam({this.image, this.options, this.newImageId});
}

class AdminImageEditScreenResult {
  final bool? deleted;

  AdminImageEditScreenResult({this.deleted});
}

class AdminImageEditScreenBloc extends BaseBloc {
  final String? imageId;
  final AdminImageEditScreenParam? param;
  final _state = BehaviorSubject<AdminImageEditScreenBlocState>();
  late var db = globalProjectsDb.db;
  ValueStream<AdminImageEditScreenBlocState> get state => _state;

  AdminImageEditScreenBloc({required this.imageId, required this.param}) {
    if (imageId == null) {
      // Creation
      _state.add(
          AdminImageEditScreenBlocState(imageId: null, image: param?.image));
    } else {
      () async {
        var image = (await dbImageStoreRef.record(imageId!).get(db));

        _state
            .add(AdminImageEditScreenBlocState(image: image, imageId: imageId));
      }();
    }
  }

  Future<void> saveImage(AdminImageEditData data) async {
    var dbImage = data.image;

    var imageData = data.imageData;
    var article = data.image;
    if (imageData != null) {
      var imageId = article.id;
      var image = img.decodeImage(imageData)!;
      var imageBaseName = stringNonEmpty(dbImage.name.v);

      if (imageBaseName != null) {
        imageBaseName = basenameWithoutExtension(imageBaseName);
      } else {
        imageBaseName = imageId;
      }
      String imageName;
      switch (data.imageFormat) {
        case ImageFormat.jpg:
          imageName = '$imageBaseName.jpg';
          break;
        case ImageFormat.png:
          imageName = '$imageBaseName.png';
          break;
      }

      var blurHash = await image.blurHashEncode();
      dbImage
        ..name.v = imageName
        ..width.v = image.width
        ..height.v = image.height
        ..blurHash.v = blurHash
        ..copyright.v = dbImage.copyright.v;

      var path =
          globalFestenaoFirebaseContext.getImageDirStoragePath(imageName);
      // devPrint('sending to $path ${imageData.length}');
      await globalFirebaseContext.storage
          .bucket()
          .file(path)
          .writeAsBytes(imageData);
    }
    if (dbImage.blurHash.v == null) {
      try {
        // Read it from network
        var imageName = dbImage.name.v!;
        var path =
            globalFestenaoFirebaseContext.getImageDirStoragePath(imageName);
        var bytes = await globalFirebaseContext.storage
            .bucket()
            .file(path)
            .readAsBytes();

        var image = img.decodeImage(bytes)!;

        dbImage.blurHash.v = await image.blurHashEncode();
      } catch (e) {
        if (kDebugMode) {
          print('error $e reading image');
        }
      }
    }

    await dbImage.put(db, merge: true);
  }

  Future<void> delete() async {
    await dbImageStoreRef.record(imageId!).delete(db);
  }

  @override
  void dispose() {
    _state.close();
    super.dispose();
  }
}

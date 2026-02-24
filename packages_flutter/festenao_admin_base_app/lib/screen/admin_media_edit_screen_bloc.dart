import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/data/festenao_storage.dart';
import 'package:festenao_common/data/src/festenao_synced_db.dart';
import 'package:flutter/foundation.dart';

import 'package:path/path.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';

// ignore: depend_on_referenced_packages

class AdminMediaEditScreenBlocState {
  final String? mediaId;

  AdminMediaEditScreenBlocState({required this.mediaId});
}

class AdminMediaEditScreenParam {
  /// From media file if any
  final FestenaoMediaFile? mediaFile;

  AdminMediaEditScreenParam({this.mediaFile});
}

class AdminMediaEditScreenResult {
  final FestenaoMediaFile? created;

  final bool? deleted;

  AdminMediaEditScreenResult({this.created, this.deleted});
}

class AdminMediaEditScreenBloc
    extends AutoDisposeStateBaseBloc<AdminMediaEditScreenBlocState> {
  final AdminMediaEditScreenParam? param;
  final FestenaoAdminAppProjectContext projectContext;
  late FestenaoSyncedDb db;
  late final dbBloc = audiAddDisposable(
    AdminAppProjectContextDbBloc(projectContext: projectContext),
  );

  String get imageStorageDirPath =>
      join(projectContext.storagePath, storageImageDirPart);
  AdminMediaEditScreenBloc({
    required this.param,
    required this.projectContext,
  }) {
    () async {
      // ignore: unused_local_variable
      var db = await dbBloc.grabFestenaoSyncedDb();
      add(AdminMediaEditScreenBlocState(mediaId: null));
    }();
  }

  /*
  Future<void> saveImage(AdminMediaEditData data) async {
    var db = await dbBloc.grabDatabase();
    var bucket = projectContext.storageBucket;
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

      var path = url.join(imageStorageDirPath, imageName);
      // devPrint('sending to $path ${imageData.length}');
      await projectContext.storage
          .bucket(bucket)
          .file(path)
          .writeAsBytes(imageData);
    }
    if (dbImage.blurHash.v == null) {
      try {
        // Read it from network
        var imageName = dbImage.name.v!;
        var path = globalFestenaoAppFirebaseContext.getImageDirStoragePath(
          imageName,
        );
        var bytes = await globalFestenaoAdminAppFirebaseContext.storage
            .bucket(bucket)
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
  */
  Future<void> delete() async {
    // ignore: unused_local_variable
    var db = await dbBloc.grabDatabase();
    //await dbImageStoreRef.record(imageId!).delete(db);
    throw UnimplementedError('delete');
  }

  /// Return the uid
  Future<String> addMediaFile(
    FestenaoMediaFile mediaFile,
    Uint8List bytes,
  ) async {
    var db = await dbBloc.grabFestenaoSyncedDb();
    var uid = await db.mediaDb.addMediaFile(file: mediaFile, bytes: bytes);
    return uid;
  }
}

import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/utils/db_utils.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

/// Image path in storage
String getImageStoragePath(String imageName) {
  return globalFestenaoFirebaseContext.getImageDirStoragePath(imageName);
}

String getImageUrl(String imageName) {
  return getUnauthenticatedStorageApi(
          projectId: globalFirebaseContext.projectId)
      .getMediaUrl(url.join(getImageStoragePath(imageName)));
}

class DbImagePreview extends StatelessWidget {
  final DbImage image;

  const DbImagePreview({super.key, required this.image});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
        aspectRatio: image.aspectRatio,
        child: Image.network(getImageUrl(image.name.v!)));
  }
}

class ImagePreview extends StatelessWidget {
  final double maxHeight;
  final String imageId;

  const ImagePreview({super.key, required this.imageId, this.maxHeight = 128});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DbImage?>(
        future: getDbImage(imageId),
        builder: (context, snapshot) {
          var dbImage = snapshot.data;
          if (dbImage == null) {
            return const Text('Pas d\'image');
          } else {
            return DbImagePreview(image: dbImage);
          }
        });
  }
}

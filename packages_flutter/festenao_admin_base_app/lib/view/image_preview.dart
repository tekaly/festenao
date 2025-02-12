import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/utils/db_utils.dart';
import 'package:festenao_common/data/festenao_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:tekartik_app_flutter_widget/app_widget.dart';

/// Image path in storage
//@Deprecated('Use getImageUrl')
String getImageStoragePath(String imageName) {
  return globalFestenaoAppFirebaseContext.getImageDirStoragePath(imageName);
}

String getImageUrl(String imageName, {required String storageBucket}) {
  return getUnauthenticatedStorageApi(storageBucket: storageBucket)
      .getMediaUrl(url.join(getImageStoragePath(imageName)));
}

class DbImagePreview extends StatelessWidget {
  final FestenaoAdminAppProjectContext projectContext;
  final DbImage image;

  const DbImagePreview(
      {super.key, required this.image, required this.projectContext});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
        aspectRatio: image.aspectRatio,
        child: Image.network(getImageUrl(
          image.name.v!,
          storageBucket: projectContext.storageBucket,
        )));
  }
}

class ImagePreview extends StatelessWidget {
  final AdminAppProjectContextDbBloc dbBloc;
  final double maxHeight;
  final String imageId;

  const ImagePreview(
      {super.key,
      required this.imageId,
      this.maxHeight = 128,
      required this.dbBloc});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: dbBloc.grabDatabase(),
        builder: (context, dbSnapshot) {
          var db = dbSnapshot.data;
          if (db == null) {
            return const SizedBox(
              height: 128,
              width: 128,
              child: CenteredProgress(),
            );
          }
          return FutureBuilder<DbImage?>(
              future: db.getDbImage(imageId),
              builder: (context, snapshot) {
                var dbImage = snapshot.data;
                if (dbImage == null) {
                  return const Text('Pas d\'image');
                } else {
                  return DbImagePreview(
                    image: dbImage,
                    projectContext: dbBloc.projectContext,
                  );
                }
              });
        });
  }
}

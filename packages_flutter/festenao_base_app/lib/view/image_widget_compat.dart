// ignore_for_file: public_member_api_docs

import 'package:festenao_base_app/db/festenao_db_compat.dart';
import 'package:festenao_base_app/src/db/firebase_compat.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:path/path.dart';

class ImageWidget extends StatefulWidget {
  final DbImage image;
  final bool noBlurHash;

  const ImageWidget({super.key, required this.image, this.noBlurHash = false});

  @override
  State<ImageWidget> createState() => _ImageWidgetState();
}

class _ImageWidgetState extends State<ImageWidget> {
  DbImage get image => widget.image;

  @override
  Widget build(BuildContext context) {
    //devPrint(gAppAssetDataImgList);
    //devPrint(image.name);
    var imageName = image.name.v;
    return AspectRatio(
      aspectRatio: image.width.v! / image.height.v!,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!widget.noBlurHash) BlurHash(hash: image.blurHash.v!),
          if (gAppAssetDataImgList.contains(imageName))
            Image(
              fit: BoxFit.cover,
              image: AssetImage(url.join(assetsDataImagePath, imageName)),
            )
          else
            Image(
              fit: BoxFit.cover,
              image: NetworkImage(
                getUnauthenticatedStorageApi(
                  projectId: appProjectId,
                ).getMediaUrl(
                  url.join(appStorageRootPath, 'image', image.name.v!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

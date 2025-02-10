import 'package:festenao_admin_base_app/admin_app/admin_app_context_db_bloc.dart';
import 'package:flutter/material.dart';

import 'image_preview.dart';

class ImageThumbnailPreview extends StatelessWidget {
  final AdminAppProjectContextDbBloc dbBloc;
  final String imageId;

  const ImageThumbnailPreview(
      {super.key, required this.imageId, required this.dbBloc});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: 32,
        height: 32,
        child: ImagePreview(
          imageId: imageId,
          dbBloc: dbBloc,
        ));
  }
}

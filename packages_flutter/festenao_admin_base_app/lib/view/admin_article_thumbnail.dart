import 'package:festenao_admin_base_app/admin_app/admin_app_context_db_bloc.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:flutter/material.dart';

import 'admin_image_thumbnail.dart';

class AdminArticleThumbnail extends StatelessWidget {
  final AdminAppProjectContextDbBloc dbBloc;
  final DbArticle article;

  const AdminArticleThumbnail({
    super.key,
    required this.article,
    required this.dbBloc,
  });

  @override
  Widget build(BuildContext context) {
    var imageId =
        (article.thumbnail.v?.isNotEmpty ?? false)
            ? article.thumbnail.v!
            : articleKindToImageId(
              article.articleKind,
              imageTypeThumbnail,
              article.id,
            );

    return ImageThumbnailPreview(imageId: imageId, dbBloc: dbBloc);
  }
}

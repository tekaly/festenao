import 'package:festenao_admin_base_app/admin_app/festenao_admin_app.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/image_preview.dart';
import 'package:festenao_admin_base_app/view/info_tile.dart';
import 'package:festenao_admin_base_app/view/menu.dart';
import 'package:festenao_admin_base_app/view/tile_padding.dart';
import 'package:festenao_common/app/app_options.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/text/text.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'admin_image_edit_screen.dart';
import 'admin_image_edit_screen_bloc.dart';

String tagsToText(Iterable<String> tags) => (tags.toList()..sort()).join(', ');

abstract class AdminArticleScreen {
  FestenaoAdminAppProjectContext get projectContext;
  AdminAppProjectContextDbBloc get dbBloc;
}

mixin AdminArticleScreenMixin implements AdminArticleScreen {
  /// 'artist', 'event', 'info', ...
  String get articleKind;
  DbArticle? get dbArticle;
  BuildContext get context;
  Widget getImagePreviewTile(DbArticle? article) {
    var imageId = article?.image.v;
    if (imageId == null) {
      return Container();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
      child: ImagePreview(imageId: imageId, dbBloc: dbBloc),
    );
  }

  Widget getImagesPreview({
    required String? articleId,
    String? articleKind,
    VoidCallback? onTap,
  }) {
    articleKind ??= this.articleKind;
    if (articleId == null) {
      return Container();
    }
    var children = <Widget>[];

    for (var imageOption in globalFestenaoAppOptions.images.v!) {
      var imageId = articleKindToImageId(
        articleKind,
        imageOption.type.v!,
        articleId,
      );
      // devPrint('imageId: $imageId');
      children.add(
        ListTile(
          onTap:
              onTap ??
              () {
                goToAdminImageEditScreen(
                  context,
                  imageId: imageId,
                  param: AdminImageEditScreenParam(options: imageOption),
                  projectContext: projectContext,
                );
              },
          title: Text(imageId),
          subtitle: SizedBox(
            height: 64,
            child: ImagePreview(imageId: imageId, dbBloc: dbBloc),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
      child: Column(children: children),
    );
  }

  Widget getTypeTile(DbArticle? article) {
    return InfoTile(
      showIfValueEmpty: false,
      label: textTypeLabel,
      value: article?.type.v,
    );
  }

  Widget getCommonTiles(DbArticle? article) {
    return Column(children: [getTypeTile(article), getTagsTile(article)]);
  }

  Widget getTagsTile(DbArticle? article) {
    return InfoTile(
      showIfValueEmpty: false,
      label: textTagsLabel,
      value: tagsToText(article?.tags.v ?? <String>[]),
    );
  }

  Widget getThumbailPreviewTile(DbArticle? article) {
    var imageId = article?.thumbnail.v;
    if (imageId == null) {
      return Container();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 128),
        child: ImagePreview(imageId: imageId, dbBloc: dbBloc),
      ),
    );
  }

  Widget getMarkdownContentTile(DbArticle? article) {
    var md = article?.content.v;
    if (md?.isEmpty ?? true) {
      return Container();
    }
    return TilePadding(
      child: MarkdownBody(
        onTapLink: (url, _, _) {
          //launch(url);
        },
        styleSheet: MarkdownStyleSheet(
          //textScaleFactor: dc.smallFontSizeRatio,
          tableBorder: TableBorder.all(color: Colors.transparent),
          p: const TextStyle(
            //color: Colors.black,
            // fontFamily: courierFontFamily,
            fontSize: 14,
          ),
          h1: const TextStyle(
            //color: Colors.black,
            // fontFamily: garageGothicFontFamily,
            fontSize: 28,
          ),
          h2: const TextStyle(
            //color: Colors.black,
            // fontFamily: garageGothicFontFamily,
            fontSize: 22,
          ),
          h3: const TextStyle(
            //color: Colors.black,
            // fontFamily: garageGothicFontFamily,
            fontSize: 18,
          ),
        ),
        data: md!,
        shrinkWrap: false,
      ),
    );
  }

  List<MenuItem> imagesMenuItems({DbArticle? dbArticle, String? articleId}) {
    var items = <MenuItem>[];
    articleId ??= (dbArticle?.idOrNull ?? this.dbArticle?.idOrNull);
    if (articleId == null) {
      // devPrint('articleId $articleId ?');
      return items;
    }

    if (globalFestenaoAppOptions.images.valueOrNull == null) {
      return items;
    }
    for (var options in globalFestenaoAppOptions.images.v!) {
      var choice = _SizeMenuChoice(options);
      items.add(
        MenuItem(
          title: choice.toString(),
          onPressed: () {
            goToAdminImageEditScreen(
              context,
              imageId: null,
              param: AdminImageEditScreenParam(
                newImageId: articleKindToImageId(
                  articleKind,
                  options.type.v!,
                  articleId!,
                ),
                image:
                    DbImage()
                      ..width.v = choice.options.width.v
                      ..height.v = choice.options.height.v,
              ),
              projectContext: projectContext,
            );
          },
        ),
      );
    }
    return items;
  }

  Widget imagesPopupMenu({DbArticle? dbArticle, String? articleId}) {
    articleId ??= (dbArticle?.idOrNull ?? this.dbArticle?.idOrNull);
    if (articleId == null) {
      // devPrint('articleId $articleId ?');
      return Container();
    }

    if (globalFestenaoAppOptions.images.valueOrNull == null) {
      return Container();
    }
    return PopupMenuButton(
      onSelected: (choice) {
        // devPrint('$choice ${this.dbArticle}');
        // devPrint('$choice $dbArticle');
        if (choice is _SizeMenuChoice) {
          var options = choice.options;
          goToAdminImageEditScreen(
            context,
            imageId: null,
            param: AdminImageEditScreenParam(
              newImageId: articleKindToImageId(
                articleKind,
                options.type.v!,
                articleId!,
              ),
              image:
                  DbImage()
                    ..width.v = choice.options.width.v
                    ..height.v = choice.options.height.v,
            ),
            projectContext: projectContext,
          );
        }
      },
      itemBuilder: (context) {
        var choices = <_MenuChoice>[];
        for (var options in globalFestenaoAppOptions.images.v!) {
          choices.add(_SizeMenuChoice(options));
        }
        return choices
            .map((e) => PopupMenuItem<_MenuChoice>(value: e, child: Text('$e')))
            .toList();
      },
    );
  }
}

class _MenuChoice {}

class _SizeMenuChoice extends _MenuChoice {
  final FestenaoAppImageOptions options;

  _SizeMenuChoice(this.options);

  @override
  String toString() => options.toString();
}

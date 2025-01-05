import 'dart:typed_data';

import 'package:festenao_admin_base_app/admin_app/festenao_admin_app.dart';
import 'package:festenao_admin_base_app/file_picker/file_picker.dart';
import 'package:festenao_admin_base_app/sembast/booklets_db.dart';
import 'package:festenao_admin_base_app/view/attributes_tile.dart';
import 'package:festenao_admin_base_app/view/image_preview.dart';
import 'package:festenao_admin_base_app/view/text_field.dart';
import 'package:festenao_admin_base_app/view/tile_padding.dart';
import 'package:festenao_common/app/src/app_options.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/text/text.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tekartik_app_flutter_common_utils/common_utils_import.dart';
import 'package:tekartik_app_http/app_http.dart';
import 'package:tekartik_app_pick_crop_image_flutter/pick_crop_image.dart';

import 'admin_article_screen_mixin.dart';
import 'admin_image_data_edit_screen.dart';
import 'admin_image_edit_screen.dart';
import 'admin_image_edit_screen_bloc.dart';

extension ArticleImageHolderExt on ArticleImageHolder {
  String get label => imageColumnLabel[articleImageColumn]!;
  String get type => imageColumnType[articleImageColumn]!;
  FestenaoAppImageOptions? get options {
    var type = this.type;
    return globalFestenaoAppOptions.getOptionsByType(type);
  }
  /*
  CvColumn<FestenaoAppImageOptions> get constraintsColumn =>
  imageColumnConstraintsColumn[articleImageColumn]!;
  FestenaoAppImageOptions get options {
    var constraintsColumn =
    imageColumnConstraintsColumn[holder.articleImageColumn];

    FestenaoAppImageOptions? constraint = constraintsColumn == null
        ? null
        : app.options
        .field<FestenaoAppImageOptions>(constraintsColumn.name)
        ?.valueOrNull;=> imageColumnConstraintsColumn[
    articleImageColumn] as FestenaoImageAppOptions;
  }*/
}

var imageColumnLabel = {
  dbArticleCommonModel.image: 'Main',
  dbArticleCommonModel.thumbnail: 'Thumb',
  dbArticleCommonModel.squareImage: 'Square',
};

var imageColumnType = {
  dbArticleCommonModel.image: imageTypeMain,
  dbArticleCommonModel.thumbnail: imageTypeThumbnail,
  dbArticleCommonModel.squareImage: imageTypeSquare,
};
/*
var imageColumnConstraintsColumn =
    <CvColumn<String>, CvColumn<FestenaoAppImageOptions>>{
  dbArticleCommonModel.image: appOptionsDefault.image.v!.main,
  dbArticleCommonModel.thumbnail: appOptionsDefault.image.v!.thumb,
  dbArticleCommonModel.squareImage: appOptionsDefault.image.v!.square,
};*/

class AdminArticleEditScreenInfo {
  /// 'artist', 'event', 'info', ...
  final String articleKind;

  AdminArticleEditScreenInfo({required this.articleKind});
}

mixin AdminArticleEditScreenMixin {
  bool get mounted;

  /// 'artist', 'event', 'info', ...
  AdminArticleEditScreenInfo get info;
  String get articleKind => info.articleKind;

  DbArticleMixin? mainArticle;

  TextEditingController? nameController;
  TextEditingController? idController;
  TextEditingController? contentController;
  TextEditingController? authorController;
  TextEditingController? subtitleController;
  TextEditingController? imageController;
  TextEditingController? typeController;
  TextEditingController? tagsController;
  TextEditingController? sortController;
  TextEditingController? thumbnailController;
  TextEditingController? quareImageController;
  ValueNotifier<List<CvAttribute>?>? attributesValueNotifier;
  List<ArticleImageHolder>? _imageHolders;

  ValueNotifier<List<CvAttribute>?> getArticleAttributes(
          DbArticleMixin? article) =>
      ValueNotifier<List<CvAttribute>?>(article?.attributes.v);
  ValueNotifier<Uint8List?>? imageBytes;
  ValueNotifier<Uint8List?>? thumbnailImageBytes;
  ValueNotifier<Uint8List?>? squareImageBytes;
  var formKey = GlobalKey<FormState>();

  Uint8List? newImageData;
  Uint8List? newThumbnailImageData;
  final saving = ValueNotifier<bool>(false);

  void articleMixinDispose() {
    thumbnailController?.dispose();
    imageController?.dispose();
    nameController?.dispose();
    idController?.dispose();
    contentController?.dispose();
    subtitleController?.dispose();
    imageBytes?.dispose();
    thumbnailImageBytes?.dispose();
    attributesValueNotifier?.dispose();
    typeController?.dispose();
    tagsController?.dispose();
    authorController?.dispose();
    sortController?.dispose();
    saving.dispose();
    if (_imageHolders != null) {
      for (var holder in _imageHolders!) {
        holder.dispose();
      }
    }
  }

  List<ArticleImageHolder> getImageHolders(DbArticleCommon? article) {
    return _imageHolders ??= articleImageHoldersColumns.map((column) {
      return ArticleImageHolder(article, column);
    }).toList();
  }

  Widget getImagesWidget(DbArticleCommon? article) {
    return Column(
      children: [
        ...getImageHolders(article).map((holder) {
          return Column(
            children: [
              AppTextFieldTile(
                emptyAllowed: true,
                controller: holder.imageIdController,
                labelText: imageColumnLabel[holder.articleImageColumn] ?? '?',
              ),
              getHolderPreviewTile(holder),
              getHolderSelectorTile(holder),
            ],
          );
        })
      ],
    );
  }

  Widget getThumbailNameWidget(DbArticleMixin? article) => AppTextFieldTile(
        emptyAllowed: true,
        controller: thumbnailController ??=
            TextEditingController(text: article?.thumbnail.v),
        labelText: textThumbnailLabel,
      );

  Widget getSquareNameWidget(DbArticleMixin? article) => AppTextFieldTile(
        emptyAllowed: true,
        controller: thumbnailController ??=
            TextEditingController(text: article?.thumbnail.v),
        labelText: textThumbnailLabel,
      );

  Widget getImageNameWidget(DbArticleMixin? article) => AppTextFieldTile(
        emptyAllowed: true,
        controller: imageController ??=
            TextEditingController(text: article?.image.v),
        labelText: textImageLabel,
      );

  Widget getCommonWidgets(DbArticle? article) {
    return Column(
      children: [
        getTypeWidget(article),
        getTagsWidget(article),
        getSortWidget(article),
      ],
    );
  }

  Widget getBottomCommonWidgets(DbArticleCommon? article) {
    return Column(
      children: [getAuthorWidget(article)],
    );
  }

  Widget getAuthorWidget(DbArticleCommon? common) {
    return AppTextFieldTile(
      emptyAllowed: true,
      controller: authorController ??=
          TextEditingController(text: common?.author.v),
      labelText: textAuthorLabel,
    );
  }

  Widget getTypeWidget(DbArticle? article) => Builder(builder: (context) {
        var types = getArticleKindTypes(articleKind);

        return Column(
          children: [
            AppTextFieldTile(
              emptyAllowed: true,
              controller: typeController ??=
                  TextEditingController(text: article?.type.v),
              labelText: textTypeLabel,
            ),
            if (types.isNotEmpty)
              Wrap(
                children: [
                  ...types.map((e) => TextButton(
                      onPressed: () {
                        typeController!.text = e;
                      },
                      child: Text(e)))
                ],
              )
          ],
        );
      });

  Widget getSortWidget(DbArticle? article) => Builder(builder: (context) {
        return Column(
          children: [
            AppTextFieldTile(
              emptyAllowed: true,
              controller: sortController ??=
                  TextEditingController(text: article?.sort.v),
              labelText: textTypeLabel,
            ),
          ],
        );
      });

  Set<String> getTagInputSet() {
    var tags = tagsController!.text.split(',').map((e) => e.trim()).toSet()
      ..removeWhere((element) => element.isEmpty);
    return tags;
  }

  Widget getTagsWidget(DbArticle? article) => Builder(builder: (context) {
        var tags = getArticleKindTags(articleKind);

        return Column(
          children: [
            AppTextFieldTile(
              emptyAllowed: true,
              controller: tagsController ??= TextEditingController(
                  text: tagsToText(article?.tags.v ?? <String>[])),
              labelText: textTagsLabel,
            ),
            if (tags.isNotEmpty)
              Wrap(
                children: [
                  ...tags.map((e) => TextButton(
                      onPressed: () {
                        var inputTags = getTagInputSet();
                        var tag = e;
                        if (inputTags.contains(tag)) {
                          inputTags.remove(tag);
                        } else {
                          inputTags.add(tag);
                        }
                        tagsController!.text = tagsToText(inputTags);
                      },
                      child: Text(e)))
                ],
              )
          ],
        );
      });

  Widget getAttributesTile(DbArticleMixin? article) {
    return AttributesTile(
        options: AttributesTileOptions(
            attributes: attributesValueNotifier ??=
                getArticleAttributes(article)));
  }

  //DbArticleCommon().
  Widget getThumbnailPreviewTile(DbArticle? article) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: TilePadding(
          child: ValueListenableBuilder<Uint8List?>(
              valueListenable: squareImageBytes ??= () {
                var valueNotifier = ValueNotifier<Uint8List?>(null);
                var squareImage = article?.squareImage.v;
                if (squareImage != null) {
                  () async {
                    var db = globalBookletsDb.db;
                    var image =
                        await dbImageStoreRef.record(squareImage).get(db);
                    if (image != null) {
                      var bytes = await httpClientFactory
                          .newClient()
                          .readBytes(Uri.parse(getImageUrl(image.name.v!)));
                      valueNotifier.value = bytes;
                    }
                  }();
                }
                return valueNotifier;
              }(),
              builder: (context, snapshot, _) {
                if (snapshot == null) {
                  return const Text('Pas d\'image');
                }
                return Image.memory(snapshot);
              }),
        ),
      );

  Widget getHolderPreviewTile(ArticleImageHolder holder) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: TilePadding(
          child: ValueListenableBuilder<Uint8List?>(
              valueListenable: holder.imageData,
              builder: (context, snapshot, _) {
                if (snapshot == null) {
                  return const Text('Pas d\'image');
                }
                return Image.memory(snapshot);
              }),
        ),
      );

  Widget getSquarePreviewTile(DbArticle? article) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: TilePadding(
          child: ValueListenableBuilder<Uint8List?>(
              valueListenable: squareImageBytes ??= () {
                var valueNotifier = ValueNotifier<Uint8List?>(null);
                var thumbnailImage = article?.thumbnail.v;
                if (thumbnailImage != null) {
                  () async {
                    var db = globalBookletsDb.db;
                    var image =
                        await dbImageStoreRef.record(thumbnailImage).get(db);
                    if (image != null) {
                      var bytes = await httpClientFactory
                          .newClient()
                          .readBytes(Uri.parse(getImageUrl(image.name.v!)));
                      valueNotifier.value = bytes;
                    }
                  }();
                }
                return valueNotifier;
              }(),
              builder: (context, snapshot, _) {
                if (snapshot == null) {
                  return const Text('Pas d\'image');
                }
                return Image.memory(snapshot);
              }),
        ),
      );

  Widget getImagePreviewTile(DbArticle? article) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: TilePadding(
          child: ValueListenableBuilder<Uint8List?>(
              valueListenable: imageBytes ??= () {
                var valueNotifier = ValueNotifier<Uint8List?>(null);
                var imageId = article?.image.v;
                if (imageId != null) {
                  () async {
                    var db = globalBookletsDb.db;
                    var image = await dbImageStoreRef.record(imageId).get(db);
                    if (image != null) {
                      var bytes = await httpClientFactory
                          .newClient()
                          .readBytes(Uri.parse(getImageUrl(image.name.v!)));
                      valueNotifier.value = bytes;
                    }
                  }();
                }
                return valueNotifier;
              }(),
              builder: (context, snapshot, _) {
                if (snapshot == null) {
                  return const Text('Pas d\'image');
                }
                return Image.memory(snapshot);
              }),
        ),
      );

  Widget getHolderSelectorTile(ArticleImageHolder holder) => TilePadding(
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              {
                var imageId = articleKindToImageId(
                    articleKind, holder.type, idController!.text);

                await goToAdminImageEditScreen(context,
                    imageId: imageId,
                    param: AdminImageEditScreenParam(options: holder.options));
              }
            },
            child: Text(
                'Selection ${holder.label} ${holder.options?.width.v}x${holder.options?.height.v ?? '?'}'),
          );
        }),
      );
  Widget getThumbnailSelectorTile(DbArticle? article) => TilePadding(
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              {
                var options = globalFestenaoAppOptions
                    .getOptionsByType(imageTypeThumbnail);
                var result = await pickCropImage(context,
                    options: PickCropImageOptions(
                        width: options?.width.v,
                        height: options?.height.v,
                        encoding: ImageEncodingJpg(quality: 50)));
                if (result != null) {
                  thumbnailImageBytes!.value = result.bytes;
                }
                return;
              }
            },
            child: const Text('Selection thumbnaiil'),
          );
        }),
      );

  Widget getSquareSelectorTile(DbArticle? article) => TilePadding(
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              {
                var options =
                    globalFestenaoAppOptions.getOptionsByType(imageTypeSquare);

                var result = await pickCropImage(context,
                    options: PickCropImageOptions(
                        width: options?.width.v,
                        height: options?.height.v,
                        encoding: ImageEncodingJpg(quality: 50)));
                if (result != null) {
                  squareImageBytes!.value = result.bytes;
                }
                return;
              }
            },
            child: const Text('Selection square'),
          );
        }),
      );

  Widget getImageSelectorTile(DbArticle? article) => TilePadding(
        child: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              var result = await pickImageFile(context);
              var file = result?.files.firstOrNull;
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${file?.name} (${file?.bytes?.length})')));
                if (file != null) {
                  var image = img.decodeImage(file.bytes!)!;

                  var result = await goToAdminImageDataEditScreen(context,
                      param: AdminImageDataEditScreenParam(bytes: file.bytes!));
                  if (result != null) {
                    if (result.cropRect != null) {
                      // devPrint(result.cropRect);
                      image = img.copyCrop(image,
                          x: result.cropRect!.left.floor(),
                          y: result.cropRect!.top.floor(),
                          width: result.cropRect!.width.floor(),
                          height: result.cropRect!.height.floor());
                      if (image.width > 1080) {
                        image = img.copyResize(image,
                            width: 1080,
                            interpolation: img.Interpolation.cubic);
                      }
                    }
                    imageBytes!.value = newImageData =
                        Uint8List.fromList(img.encodeJpg(image, quality: 50));
                  }
                }
              }
            },
            child: const Text('Selection image'),
          );
        }),
      );
  void articleFromForm(DbArticleMixin article) {
    article
      ..name.v = nameController!.text
      ..subtitle.v = subtitleController!.text
      ..content.v = contentController!.text
      ..thumbnail.v = thumbnailController!.text
      ..type.v = typeController!.text
      ..tags.v = (getTagInputSet().toList()..sort())
      ..image.v = imageController!.text
      ..attributes.v = attributesValueNotifier!.value
      ..author.v = authorController!.text;
  }
}

class ArticleImageHolder {
  TextEditingController? _imageIdController;
  TextEditingController get imageIdController =>
      _imageIdController ??= TextEditingController(text: _articleImageId);
  final _fetchLock = Lock();
  final _imageData = ValueNotifier<Uint8List?>(null);
  final DbArticleCommon? article;
  late final CvColumn<String> articleImageColumn;
  String? _imageDataId;

  void dispose() {
    _imageData.dispose();
    _imageIdController?.dispose();
  }

  String? get _articleImageId {
    return imageField?.valueOrNull;
  }

  CvField<String>? get imageField =>
      article?.field<String>(articleImageColumn.name);
  ArticleImageHolder(this.article, this.articleImageColumn);

  void _setNull() {
    _imageData.value = null;
    _imageDataId = null;
  }

  void selectImage(Uint8List bytes) {
    _imageData.value = bytes;
  }

  void _set(String imageId, Uint8List bytes) {
    _imageData.value = bytes;
    _imageDataId = imageId;
  }

  ValueNotifier<Uint8List?> get imageData {
    if (_imageDataId != _articleImageId || (_articleImageId == null)) {
      _setNull();
    }
    if (_imageData.value == null && _articleImageId != null) {
      _fetchLock.synchronized(() async {
        var imageId = _articleImageId;
        if (imageId != null) {
          if (_imageData.value == null || _imageDataId != imageId) {
            var db = globalBookletsDb.db;
            var image = await dbImageStoreRef.record(imageId).get(db);
            if (image != null) {
              var bytes = await httpClientFactory
                  .newClient()
                  .readBytes(Uri.parse(getImageUrl(image.name.v!)));
              _set(imageId, bytes);
            }
          }
        }
      }).unawait();
    }
    return _imageData;
  }
}

final articleImageHoldersColumns = <CvColumn<String>>[
  dbArticleCommonModel.image,
  dbArticleCommonModel.squareImage,
  dbArticleCommonModel.thumbnail
];

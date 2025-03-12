import 'package:festenao_admin_base_app/admin_app/festenao_admin_app.dart';
import 'package:festenao_admin_base_app/download/download_image.dart';
import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/image_preview.dart';
import 'package:festenao_admin_base_app/view/linear_wait.dart';
import 'package:festenao_admin_base_app/view/text_field.dart';
import 'package:festenao_admin_base_app/view/tile_padding.dart';
import 'package:festenao_blur_hash/blur_hash.dart';
import 'package:festenao_common/text/text.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:tekartik_app_http/app_http.dart';
import 'package:tekartik_app_pick_crop_image_flutter/pick_crop_image.dart';

import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_admin_app/view/body_container.dart';

import 'admin_article_edit_screen_mixin.dart';
import 'admin_image_edit_screen_bloc.dart';

class AdminImageEditData {
  final DbImage image;
  Uint8List? imageData;
  final ImageFormat imageFormat;

  AdminImageEditData({
    required this.image,
    this.imageData,
    required this.imageFormat,
  });
}

class AdminImageEditScreen extends StatefulWidget {
  const AdminImageEditScreen({super.key});

  @override
  State<AdminImageEditScreen> createState() => _AdminImageEditScreenState();
}

class _AdminImageEditScreenState extends State<AdminImageEditScreen>
    with AdminArticleEditScreenMixin {
  @override
  FestenaoAdminAppProjectContext get projectContext => bloc.projectContext;
  TextEditingController? widthController;
  TextEditingController? heightController;
  TextEditingController? copyrightController;
  TextEditingController? blurHashController;
  final _imageFormat = BehaviorSubject<ImageFormat>.seeded(
    globalFestenaoAdminApp.prefsImageFormat,
  );

  @override
  void dispose() {
    articleMixinDispose();
    heightController?.dispose();
    widthController?.dispose();
    copyrightController?.dispose();
    blurHashController?.dispose();
    _imageFormat.close();
    super.dispose();
  }

  void _setFormat(ImageFormat format) {
    _imageFormat.add(format);
    globalFestenaoAdminApp.prefsImageFormat = format;
    var imageName =
        '${basenameWithoutExtension(stringNonEmpty(nameController!.text.trim()) ?? idController!.text.trim())}${imageFormatExtension(format)}';
    nameController!.text = imageName;
  }

  AdminImageEditScreenBloc get bloc =>
      BlocProvider.of<AdminImageEditScreenBloc>(this.context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    var param = bloc.param;
    return ValueStreamBuilder<AdminImageEditScreenBlocState>(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;

        var image = state?.image;
        var imageId = bloc.imageId;
        var canSave = snapshot.hasData; // imageId == null || image != null;
        return AdminScreenLayout(
          appBar: AppBar(
            actions: [
              if (bloc.imageId != null)
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Supprimer',
                  onPressed: () {
                    _onDelete(context);
                  },
                ),
            ],
            title: const Text('Image'),
          ),
          body: Builder(
            builder: (context) {
              if (!canSave) {
                return const Center(child: CircularProgressIndicator());
              }
              // devPrint('canSave $canSave $eventId $event');

              return Stack(
                children: [
                  ListView(
                    children: [
                      Form(
                        key: formKey,
                        child: BodyContainer(
                          child: Column(
                            children: [
                              if (image == null && imageId != null)
                                const ListTile(title: Text('Non trouvé'))
                              else ...[
                                ListTile(title: Text(imageId ?? 'new')),
                              ],
                              AppTextFieldTile(
                                controller:
                                    idController ??= TextEditingController(
                                      text: imageId ?? param?.newImageId,
                                    ),
                                labelText: textIdLabel,
                              ),
                              AppTextFieldTile(
                                controller:
                                    nameController ??= TextEditingController(
                                      text: image?.name.v,
                                    ),
                                emptyAllowed: true,
                                labelText: textNameLabel,
                              ),
                              AppTextFieldTile(
                                controller:
                                    copyrightController ??=
                                        TextEditingController(
                                          text: image?.copyright.v,
                                        ),
                                emptyAllowed: true,
                                labelText: textCopyrightLabel,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppTextFieldTile(
                                      controller:
                                          widthController ??=
                                              TextEditingController(
                                                text:
                                                    (image?.width.v ??
                                                            param
                                                                ?.options
                                                                ?.width
                                                                .v)
                                                        ?.toString(),
                                              ),
                                      emptyAllowed: true,
                                      labelText: textWidthLabel,
                                    ),
                                  ),
                                  Expanded(
                                    child: AppTextFieldTile(
                                      controller:
                                          heightController ??=
                                              TextEditingController(
                                                text:
                                                    (image?.height.v ??
                                                            param
                                                                ?.options
                                                                ?.height
                                                                .v)
                                                        ?.toString(),
                                              ),
                                      validator: (text) => null,
                                      labelText: textHeightLabel,
                                    ),
                                  ),
                                  Expanded(
                                    child: AppTextFieldTile(
                                      readOnly: true,
                                      controller:
                                          blurHashController ??=
                                              TextEditingController(
                                                text: image?.blurHash.v,
                                              ),
                                      labelText: textBlurHashLabel,
                                      validator: (text) => null,
                                    ),
                                  ),
                                ],
                              ),
                              ValueStreamBuilder<ImageFormat>(
                                stream: _imageFormat,
                                builder: (context, snapshot) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: RadioListTile<ImageFormat>(
                                          value: ImageFormat.jpg,
                                          groupValue: _imageFormat.valueOrNull,
                                          onChanged: (_) {
                                            _setFormat(ImageFormat.jpg);
                                          },
                                          title: const Text('JPG'),
                                        ),
                                      ),
                                      Expanded(
                                        child: RadioListTile<ImageFormat>(
                                          value: ImageFormat.png,
                                          groupValue: _imageFormat.valueOrNull,
                                          onChanged: (_) {
                                            _setFormat(ImageFormat.png);
                                          },
                                          title: const Text('PNG'),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              getAdminImageSelectorTile(),
                              getPreviewImage(),
                              ElevatedButton(
                                onPressed: () async {
                                  await appDownloadImage(
                                    DownloadImageInfo(
                                      filename: nameController!.text,
                                      data: imageBytes!.value!,
                                    ),
                                  );
                                },
                                child: const Text('Download image'),
                              ),
                              const SizedBox(height: 64),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  LinearWait(showNotifier: saving),
                ],
              );
            },
          ),
          floatingActionButton:
              canSave
                  ? FloatingActionButton(
                    onPressed: () => _onSave(context),
                    child: const Icon(Icons.save),
                  )
                  : null,
        );
      },
    );
  }

  Widget getAdminImageSelectorTile() => TilePadding(
    child: Builder(
      builder: (context) {
        return ElevatedButton(
          onPressed: () async {
            {
              ImageEncoding encoding;
              switch (_imageFormat.value) {
                case ImageFormat.jpg:
                  encoding = ImageEncodingJpg(quality: 50);
                  break;
                case ImageFormat.png:
                  encoding = const ImageEncodingPng();
                  break;
              }
              var result = await pickCropImage(
                context,
                options: PickCropImageOptions(
                  width: parseInt(widthController!.text),
                  height: parseInt(heightController!.text),
                  encoding: encoding,
                ),
              );
              if (result != null) {
                //print('Selected $result');
                imageBytes!.value = newImageData = result.bytes;
                widthController!.text = result.width.toString();
                heightController!.text = result.height.toString();
                blurHashController!.text = await festenaoBlurHashEncode(
                  result.bytes,
                );
              }
              return;
            }
          },
          child: const Text('Selection image'),
        );
      },
    ),
  );

  Widget getPreviewImage([String? imageId]) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: TilePadding(
      child: ValueListenableBuilder<Uint8List?>(
        valueListenable:
            imageBytes ??= () {
              var valueNotifier = ValueNotifier<Uint8List?>(null);

              if (imageId != null) {
                () async {
                  var db = await dbBloc.grabDatabase();
                  var image = await dbImageStoreRef.record(imageId).get(db);
                  if (image != null) {
                    var imageUrl = Uri.parse(
                      getImageUrl(
                        image.name.v!,
                        storageBucket: projectContext.storageBucket,
                      ),
                    );
                    // print('imageUrl: $imageUrl');
                    var bytes = await httpClientFactory.newClient().readBytes(
                      imageUrl,
                    );
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
        },
      ),
    ),
  );

  final _saveLock = Lock();

  Future<void> _onSave(BuildContext context) async {
    if (formKey.currentState!.validate() && !_saveLock.locked) {
      await _saveLock.synchronized(() async {
        try {
          saving.value = true;
          var bloc = BlocProvider.of<AdminImageEditScreenBloc>(context);
          formKey.currentState!.save();
          var dbImage = DbImage();

          imageFromForm(dbImage);
          await bloc.saveImage(
            AdminImageEditData(
              image: dbImage,
              imageData: newImageData,
              imageFormat: _imageFormat.value,
            ),
          );
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        } catch (e, st) {
          if (kDebugMode) {
            print(e);
            print(st);
          }
        } finally {
          saving.value = false;
        }
      });
    }
  }

  void imageFromForm(DbImage image) {
    image
      ..rawRef = dbImageStoreRef.record(idController!.text).rawRef
      ..name.v = nameController!.text
      ..width.v = parseInt(widthController!.text)
      ..height.v = parseInt(heightController!.text)
      ..copyright.v = copyrightController!.text;
  }

  Future<void> _onDelete(BuildContext context) async {
    if (!_saveLock.locked) {
      await _saveLock.synchronized(() async {
        try {
          saving.value = true;
          var bloc = BlocProvider.of<AdminImageEditScreenBloc>(context);
          await bloc.delete();
          if (context.mounted) {
            Navigator.of(
              context,
            ).pop(AdminImageEditScreenResult(deleted: true));
          }
        } catch (e, st) {
          if (kDebugMode) {
            print(e);
            print(st);
          }
        } finally {
          saving.value = false;
        }
      });
    }
  }

  @override
  AdminArticleEditScreenInfo get info => throw UnimplementedError();

  @override
  AdminAppProjectContextDbBloc get dbBloc => bloc.dbBloc;
}

Future<AdminImageEditScreenResult?> goToAdminImageEditScreen(
  BuildContext context, {
  required String? imageId,
  AdminImageEditScreenParam? param,
  required FestenaoAdminAppProjectContext projectContext,
}) async {
  var result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder: (context) {
        return BlocProvider(
          blocBuilder:
              () => AdminImageEditScreenBloc(
                imageId: imageId,
                param: param,
                projectContext: projectContext,
              ),
          child: const AdminImageEditScreen(),
        );
      },
    ),
  );
  if (result is AdminImageEditScreenResult) {
    return result;
  }
  return null;
}

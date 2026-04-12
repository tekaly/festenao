import 'package:festenao_admin_base_app/admin_app/festenao_admin_app.dart';
import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/image_preview.dart';
import 'package:festenao_admin_base_app/view/linear_wait.dart';
import 'package:festenao_admin_base_app/view/tile_padding.dart';

import 'package:festenao_common/data/festenao_media.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tekartik_app_http/app_http.dart';
import 'package:tekartik_common_utils/byte_utils.dart';

import 'package:tkcms_admin_app/view/body_container.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';
import 'package:tkcms_user_app/view/rx_busy_indicator.dart';

import 'admin_article_edit_screen_mixin.dart';
import 'admin_media_edit_screen_bloc.dart';

class AdminMediaEditData {
  final DbImage image;
  Uint8List? imageData;
  final ImageFormat imageFormat;

  AdminMediaEditData({
    required this.image,
    this.imageData,
    required this.imageFormat,
  });
}

class AdminMediaEditScreen extends StatefulWidget {
  const AdminMediaEditScreen({super.key});

  @override
  State<AdminMediaEditScreen> createState() => _AdminMediaEditScreenState();
}

class _AdminMediaEditScreenState
    extends AutoDisposeBaseState<AdminMediaEditScreen>
    with
        AdminArticleEditScreenMixin,
        AutoDisposedBusyScreenStateMixin<AdminMediaEditScreen> {
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

  AdminMediaEditScreenBloc get bloc =>
      BlocProvider.of<AdminMediaEditScreenBloc>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    return ValueStreamBuilder<AdminMediaEditScreenBlocState>(
      stream: bloc.state,
      builder: (context, snapshot) {
        /*
        var image = state?.image;
        var imageId = bloc.imageId;*/
        var canSave = snapshot.hasData; // imageId == null || image != null;
        return AdminScreenLayout(
          appBar: AppBar(
            actions: [
              if (bloc.param?.mediaFile != null)
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Supprimer',
                  onPressed: () {
                    _onDelete(context);
                  },
                ),
            ],
            title: const Text('Media'),
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
                              const Text('TODO'),
                              getAdminMediaSelectorTile(),
                              /*
                              if (image == null && imageId != null)
                                const ListTile(title: Text('Non trouvé'))
                              else ...[
                                ListTile(title: Text(imageId ?? 'new')),
                              ],
                              AppTextFieldTile(
                                controller: idController ??=
                                    TextEditingController(
                                      text: imageId ?? param?.newImageId,
                                    ),
                                labelText: textIdLabel,
                              ),
                              AppTextFieldTile(
                                controller: nameController ??=
                                    TextEditingController(text: image?.name.v),
                                emptyAllowed: true,
                                labelText: textNameLabel,
                              ),
                              AppTextFieldTile(
                                controller: copyrightController ??=
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
                                      controller: widthController ??=
                                          TextEditingController(
                                            text:
                                                (image?.width.v ??
                                                        param?.options?.width.v)
                                                    ?.toString(),
                                          ),
                                      emptyAllowed: true,
                                      labelText: textWidthLabel,
                                    ),
                                  ),
                                  Expanded(
                                    child: AppTextFieldTile(
                                      controller: heightController ??=
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
                                      controller: blurHashController ??=
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
                                  return RadioGroup<ImageFormat>(
                                    groupValue: _imageFormat.valueOrNull,
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      _setFormat(value);
                                    },
                                    child: const Row(
                                      children: [
                                        Expanded(
                                          child: RadioListTile<ImageFormat>(
                                            value: ImageFormat.jpg,

                                            title: Text('JPG'),
                                          ),
                                        ),
                                        Expanded(
                                          child: RadioListTile<ImageFormat>(
                                            value: ImageFormat.png,

                                            title: Text('PNG'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

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
                              ),*/
                              const SizedBox(height: 64),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  BusyIndicator(busy: busyStream),
                  LinearWait(showNotifier: saving),
                ],
              );
            },
          ),
          floatingActionButton: canSave
              ? FloatingActionButton(
                  onPressed: () => _onSave(context),
                  child: const Icon(Icons.save),
                )
              : null,
        );
      },
    );
  }

  Widget getAdminMediaSelectorTile() => TilePadding(
    child: Builder(
      builder: (context) {
        return ElevatedButton(
          onPressed: () async {
            {
              var ffpResult = await FilePicker.pickFiles(
                allowMultiple: false,
                withReadStream: true,

                //allowedExtensions: ['.jpg', '.JPG', '.png', '.PNG']
              );

              if (ffpResult == null) {
                return;
              }
              var file = ffpResult.files.firstOrNull!;
              await busyAction(() async {
                /// Convert to bytes
                var bytes = await listStreamGetBytes(file.readStream!);

                var mediaFile = FestenaoMediaFile.from(filename: file.name);
                await bloc.addMediaFile(mediaFile, bytes);

                await sleep(1000);
              });

              return;
            }
          },
          child: const Text('Selection fichier'),
        );
      },
    ),
  );

  Widget getPreviewImage([String? imageId]) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: TilePadding(
      child: ValueListenableBuilder<Uint8List?>(
        valueListenable: imageBytes ??= () {
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
          BlocProvider.of<AdminMediaEditScreenBloc>(context);
          formKey.currentState!.save();
          /*
          var dbImage = DbImage();

          imageFromForm(dbImage);

          await bloc.saveImage(
            AdminMediaEditData(
              image: dbImage,
              imageData: newImageData,
              imageFormat: _imageFormat.value,
            ),
          );
          if (context.mounted) {
            Navigator.of(context).pop();
          }*/
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
          var bloc = BlocProvider.of<AdminMediaEditScreenBloc>(context);
          await bloc.delete();
          if (context.mounted) {
            Navigator.of(
              context,
            ).pop(AdminMediaEditScreenResult(deleted: true));
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

Future<AdminMediaEditScreenResult?> goToAdminMediaEditScreen(
  BuildContext context, {
  required String? mediaId,
  AdminMediaEditScreenParam? param,
  required FestenaoAdminAppProjectContext projectContext,
}) async {
  var result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder: (context) {
        return BlocProvider(
          blocBuilder: () => AdminMediaEditScreenBloc(
            //imageId: imageId,
            param: param,
            projectContext: projectContext,
          ),
          child: const AdminMediaEditScreen(),
        );
      },
    ),
  );
  if (result is AdminMediaEditScreenResult) {
    return result;
  }
  return null;
}

// ignore_for_file: depend_on_referenced_packages

import 'package:festenao_admin_base_app/admin_app/admin_app_project_context.dart';
import 'package:festenao_admin_base_app/admin_app/festenao_admin_app.dart';
import 'package:festenao_admin_base_app/audio/cache.dart';
import 'package:festenao_admin_base_app/audio/player.dart';
import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/view/text_field.dart';
import 'package:festenao_audio_player/player.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/text/text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:tekartik_app_flutter_bloc/bloc_provider.dart';
import 'package:tekartik_app_flutter_common_utils/common_utils_import.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tekartik_app_rx_utils/app_rx_utils.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_admin_app/view/body_container.dart';
import 'package:tkcms_admin_app/view/body_h_padding.dart';

import 'admin_infos_screen.dart';
import 'admin_screen_mixin.dart';

class AdminAttributeEditScreenBlocState {
  final CvAttribute? attribute;

  AdminAttributeEditScreenBlocState({this.attribute});
}

class AdminAttributeEditScreenParam {
  final CvAttribute? attribute;

  AdminAttributeEditScreenParam({this.attribute});
}

class AdminAttributeEditScreenResult {
  final bool? deleted;
  final CvAttribute? attribute;

  AdminAttributeEditScreenResult({this.deleted, this.attribute});
}

class AdminAttributeEditScreenBloc
    extends AutoDisposeStateBaseBloc<AdminAttributeEditScreenBlocState> {
  final FestenaoAdminAppProjectContext projectContext;
  final AdminAttributeEditScreenParam? param;

  AdminAttributeEditScreenBloc({
    required this.param,
    required this.projectContext,
  }) {
    // Creation
    add(AdminAttributeEditScreenBlocState(attribute: param?.attribute));
  }
}

class AdminAttributeEditScreen extends StatefulWidget {
  const AdminAttributeEditScreen({super.key});

  @override
  State<AdminAttributeEditScreen> createState() =>
      _AdminAttributeEditScreenState();
}

class _AdminAttributeEditScreenState extends State<AdminAttributeEditScreen>
    with AdminScreenMixin {
  final formKey = GlobalKey<FormState>();
  TextEditingController? nameController;
  TextEditingController? typeController;
  TextEditingController? linkController;

  @override
  void dispose() {
    linkController?.dispose();
    typeController?.dispose();
    nameController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<AdminAttributeEditScreenBloc>(context);
    return ValueStreamBuilder<AdminAttributeEditScreenBlocState>(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;

        var attribute = state?.attribute;
        var canSave = state != null;

        return AdminScreenLayout(
          appBar: AppBar(
            actions: [
              if (canSave)
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Supprimer',
                  onPressed: () {
                    _onDelete(context);
                  },
                ),
            ],
            title: const Text('Attribute'),
          ),
          body: Builder(
            builder: (context) {
              if (!canSave) {
                return const Center(child: CircularProgressIndicator());
              }
              // devPrint('canSave $canSave $attributeId $attribute');

              nameController ??= TextEditingController(text: attribute?.name.v);
              if (typeController == null) {
                sleep(0).then((_) {
                  _handleType();
                  typeController!.addListener(() {
                    _handleType();
                  });
                });
              }
              return Stack(
                children: [
                  ListView(
                    children: [
                      Form(
                        key: formKey,
                        child: BodyContainer(
                          child: Column(
                            children: [
                              AppTextFieldTile(
                                controller: nameController,
                                emptyAllowed: true,
                                labelText: textNameLabel,
                              ),
                              getTypeWidget(attribute),
                              AppTextFieldTile(
                                controller: linkController ??=
                                    TextEditingController(
                                      text: attribute?.value.v,
                                    ),
                                emptyAllowed: true,
                                labelText: textLinkLabel,
                              ),
                            ],
                          ),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: showAudioNotifier,
                        builder: (context, snapshot, _) {
                          if (!snapshot) {
                            return Container();
                          }
                          // TODO handle cache ready.
                          initAudioCache(packageName: globalPackageName);
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BodyContainer(
                                child: AppAudioPlayerWidget(
                                  player: globalAppAudioPlayer,
                                  song: AppAudioPlayerSong(
                                    linkController!.text,
                                  ),
                                ),
                              ),
                              BodyContainer(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      FloatingActionButton(
                                        onPressed: () async {
                                          await initAudioCache(
                                            packageName: globalPackageName,
                                          );
                                          await globalAppAudioPlayer.playSong(
                                            AppAudioPlayerSong(
                                              linkController!.text,
                                            ),
                                          );
                                        },
                                        child: const Icon(Icons.play_arrow),
                                      ),
                                      const SizedBox(width: 8),
                                      FloatingActionButton(
                                        onPressed: () async {
                                          await globalAppAudioPlayer.stop();
                                        },
                                        child: const Icon(Icons.stop),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      BodyContainer(
                        child: BodyHPadding(
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  var info = await selectInfo(
                                    context,
                                    infoType: infoTypeSong,
                                    projectContext: bloc.projectContext,
                                  );
                                  var dbInfo = info?.info;
                                  if (dbInfo != null) {
                                    linkController!.text =
                                        '${dbInfoStoreRef.name}:${dbInfo.id}';
                                  }
                                },
                                child: const Text('Select song'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          floatingActionButton: canSave
              ? FloatingActionButton(
                  heroTag: UniqueKey(),
                  onPressed: () => _onSave(context),
                  child: const Icon(Icons.save),
                )
              : null,
        );
      },
    );
  }

  Widget getTypeWidget(
    CvAttribute? attribute, {
    ValueChanged<String>? onChanged,
  }) => Builder(
    builder: (context) {
      var types = attributeTypes;

      return Column(
        children: [
          AppTextFieldTile(
            emptyAllowed: true,
            controller: typeController ??= TextEditingController(
              text: attribute?.type.v,
            ),
            labelText: textTypeLabel,
            onChanged: onChanged,
          ),
          Wrap(
            children: [
              ...types.map(
                (e) => TextButton(
                  onPressed: () {
                    typeController!.text = e;
                  },
                  child: Text(e),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  final _saveLock = Lock();

  Future<void> _onSave(BuildContext context) async {
    if (formKey.currentState!.validate() && !_saveLock.locked) {
      await _saveLock.synchronized(() async {
        try {
          formKey.currentState!.save();
          var attribute = CvAttribute()
            ..name.v = nameController!.text
            ..type.v = typeController!.text
            ..value.v = linkController!.text;

          // All empty not allowed
          if (stringIsEmpty(attribute.name.v) &&
              stringIsEmpty(attribute.type.v) &&
              stringIsEmpty(attribute.value.v)) {
            snack(context, 'Nom ou type ou Lien ne doit pas etre vide');
            return;
          }
          Navigator.of(
            context,
          ).pop(AdminAttributeEditScreenResult(attribute: attribute));
        } catch (e, st) {
          if (kDebugMode) {
            print(e);
            print(st);
          }
        } finally {}
      });
    }
  }

  Future<void> _onDelete(BuildContext context) async {
    if (!_saveLock.locked) {
      await _saveLock.synchronized(() async {
        try {
          Navigator.of(
            context,
          ).pop(AdminAttributeEditScreenResult(deleted: true));
        } catch (e, st) {
          if (kDebugMode) {
            print(e);
            print(st);
          }
        } finally {}
      });
    }
  }

  var showAudioNotifier = ValueNotifier(false);

  void _handleType() {
    // devPrint('handle type: ${typeController?.text}');
    var isAudio = typeController?.text == attributeTypeAudio;
    showAudioNotifier.value = isAudio;
  }
}

Future<AdminAttributeEditScreenResult?> goToAdminAttributeEditScreen(
  BuildContext context, {
  required AdminAttributeEditScreenParam? param,
  required FestenaoAdminAppProjectContext projectContext,
}) async {
  return await Navigator.of(context).push<AdminAttributeEditScreenResult>(
    MaterialPageRoute(
      builder: (context) {
        return BlocProvider(
          blocBuilder: () => AdminAttributeEditScreenBloc(
            param: param,
            projectContext: projectContext,
          ),
          child: const AdminAttributeEditScreen(),
        );
      },
    ),
  );
}

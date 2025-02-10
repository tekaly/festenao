import 'package:festenao_admin_base_app/admin_app/admin_app_context_db_bloc.dart';
import 'package:festenao_admin_base_app/admin_app/admin_app_project_context.dart';
import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/view/linear_wait.dart';
import 'package:festenao_admin_base_app/view/text_field.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/text/text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_bloc/bloc_provider.dart';
import 'package:tekartik_app_flutter_common_utils/common_utils_import.dart';
import 'package:tekartik_app_rx_utils/app_rx_utils.dart';
import 'package:tkcms_admin_app/view/body_container.dart';

import 'admin_article_edit_screen_bloc_mixin.dart';
import 'admin_article_edit_screen_mixin.dart';
import 'admin_info_edit_screen_bloc.dart';

class AdminInfoEditScreen extends StatefulWidget {
  const AdminInfoEditScreen({super.key});

  @override
  State<AdminInfoEditScreen> createState() => _AdminInfoEditScreenState();
}

class _AdminInfoEditScreenState extends State<AdminInfoEditScreen>
    with AdminArticleEditScreenMixin {
  TextEditingController? beginTimeController;
  TextEditingController? endTimeController;
  TextEditingController? dayController;

  @override
  void dispose() {
    articleMixinDispose();
    dayController?.dispose();
    beginTimeController?.dispose();
    endTimeController?.dispose();
    super.dispose();
  }

  AdminInfoEditScreenBloc get bloc =>
      BlocProvider.of<AdminInfoEditScreenBloc>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    return ValueStreamBuilder<AdminInfoEditScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var state = snapshot.data;

          var info = state?.info;
          var infoId = bloc.infoId;
          var canSave = infoId == null || info != null;

          return AdminScreenLayout(
            appBar: AppBar(
              actions: [
                if (bloc.infoId != null)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Supprimer',
                    onPressed: () {
                      _onDelete(context);
                    },
                  ),
              ],
              title: const Text('Info'),
            ),
            body: Builder(
              builder: (context) {
                if (!canSave) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                // devPrint('canSave $canSave $infoId $info');
                var article = info;
                return Stack(
                  children: [
                    ListView(children: [
                      Form(
                        key: formKey,
                        child: BodyContainer(
                          child: Column(children: [
                            if (info == null && infoId != null)
                              const ListTile(
                                title: Text('Non trouvé'),
                              )
                            else ...[
                              ListTile(
                                title: Text(info?.id ?? 'new'),
                              ),
                            ],
                            AppTextFieldTile(
                              controller: idController ??=
                                  TextEditingController(text: info?.id),
                              readOnly: infoId != null,
                              labelText: textIdLabel,
                            ),
                            getCommonWidgets(article),
                            AppTextFieldTile(
                              controller: nameController ??=
                                  TextEditingController(text: info?.name.v),
                              emptyAllowed: true,
                              labelText: textNameLabel,
                            ),
                            AppTextFieldTile(
                              controller: subtitleController ??=
                                  TextEditingController(text: info?.subtitle.v),
                              emptyAllowed: true,
                              labelText: textSubtitleLabel,
                            ),
                            AppTextFieldTile(
                              controller: contentController ??=
                                  TextEditingController(text: info?.content.v),
                              maxLines: 10,
                              emptyAllowed: true,
                              labelText: 'Contenu',
                            ),
                            getBottomCommonWidgets(article),
                            getAttributesTile(article),
                            getThumbailNameWidget(article),
                            getThumbnailSelectorTile(article),
                            getThumbnailPreviewTile(article),
                            getImageNameWidget(article),
                            getImageSelectorTile(article),
                            getImagePreviewTile(article),
                            const SizedBox(
                              height: 64,
                            ),
                          ]),
                        ),
                      )
                    ]),
                    LinearWait(
                      showNotifier: saving,
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
        });
  }

  final _saveLock = Lock();

  Future<void> _onSave(BuildContext context) async {
    if (formKey.currentState!.validate() && !_saveLock.locked) {
      await _saveLock.synchronized(() async {
        try {
          saving.value = true;
          var bloc = BlocProvider.of<AdminInfoEditScreenBloc>(context);
          formKey.currentState!.save();
          var dbInfo = DbInfo()
            ..rawRef = dbInfoStoreRef.record(idController!.text).rawRef;
          articleFromForm(dbInfo);
          await bloc.save(
              AdminArticleEditData(article: dbInfo, imageData: newImageData));
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

  Future<void> _onDelete(BuildContext context) async {
    if (!_saveLock.locked) {
      await _saveLock.synchronized(() async {
        try {
          saving.value = true;
          var bloc = BlocProvider.of<AdminInfoEditScreenBloc>(context);
          await bloc.delete();
          if (context.mounted) {
            Navigator.of(context).pop(AdminInfoEditScreenResult(deleted: true));
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
  @override
  AdminArticleEditScreenInfo get info =>
      AdminArticleEditScreenInfo(articleKind: articleKindInfo);

  @override
  FestenaoAdminAppProjectContext get projectContext => bloc.projectContext;

  @override
  AdminAppProjectContextDbBloc get dbBloc => bloc.dbBloc;
}

Future<AdminInfoEditScreenResult?> goToAdminInfoEditScreen(BuildContext context,
    {required String? infoId,
    DbInfo? info,
    required FestenaoAdminAppProjectContext projectContext}) async {
  var result = await Navigator.of(context)
      .push<Object?>(MaterialPageRoute(builder: (context) {
    return BlocProvider(
        blocBuilder: () => AdminInfoEditScreenBloc(
            infoId: infoId, info: info, projectContext: projectContext),
        child: const AdminInfoEditScreen());
  }));
  if (result is AdminInfoEditScreenResult) {
    return result;
  }
  return null;
}

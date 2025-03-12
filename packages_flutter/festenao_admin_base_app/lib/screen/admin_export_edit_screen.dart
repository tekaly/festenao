import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/info_tile.dart';
import 'package:festenao_admin_base_app/view/linear_wait.dart';
import 'package:festenao_common/text/text.dart';
import 'package:flutter/foundation.dart';

import 'admin_export_edit_screen_bloc.dart';

class AdminExportEditScreen extends StatefulWidget {
  const AdminExportEditScreen({super.key});

  @override
  State<AdminExportEditScreen> createState() => _AdminExportEditScreenState();
}

class _AdminExportEditScreenState extends State<AdminExportEditScreen> {
  var formKey = GlobalKey<FormState>();
  final saving = ValueNotifier<bool>(false);
  ValueNotifier<bool>? exportNotifier;
  ValueNotifier<bool>? publishDevNotifier;
  ValueNotifier<bool>? publishProdNotifier;

  @override
  void dispose() {
    saving.dispose();
    exportNotifier?.dispose();
    publishDevNotifier?.dispose();
    publishProdNotifier?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<AdminExportEditScreenBloc>(context);
    return ValueStreamBuilder<AdminExportEditScreenBlocState>(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;

        var export = state?.fsExport;

        var canSave = export != null;

        if (canSave) {
          if (export.changeId.v == state!.metaInfo.lastChangeId.v) {
            exportNotifier = ValueNotifier<bool>(export.timestamp.v == null);
          }

          publishDevNotifier = ValueNotifier<bool>(true);
          publishProdNotifier = ValueNotifier<bool>(true);
        }
        return AdminScreenLayout(
          appBar: AppBar(title: const Text('Export v2')),
          body: Stack(
            children: [
              ValueStreamBuilder<AdminExportEditScreenBlocState>(
                stream: bloc.state,
                builder: (context, snapshot) {
                  var state = snapshot.data;
                  if (!canSave) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var export = state?.fsExport;
                  var exportId = bloc.exportId;
                  if (export == null) {
                    return Container();
                  }
                  return ListView(
                    children: [
                      Form(
                        key: formKey,
                        child: Column(
                          children: [
                            if (canSave && exportId != null) ...[
                              if (!export.exists)
                                const ListTile(title: Text('Not found')),
                            ] else ...[
                              ListTile(title: Text(exportId ?? 'New export')),
                            ],
                            if (export.version.v != null)
                              InfoTile(
                                label: textVersion,
                                value: export.version.v?.toString() ?? '?',
                              ),
                            InfoTile(
                              label: textChangeId,
                              value: export.changeId.v?.toString() ?? '?',
                            ),
                            if (export.timestamp.v != null)
                              InfoTile(
                                label: textTimestamp,
                                value:
                                    export.timestamp.v?.toIso8601String() ??
                                    '?',
                              ),
                            if (export.size.v != null)
                              InfoTile(
                                label: textSize,
                                value: export.size.v?.toString() ?? '?',
                              ),
                            if (exportNotifier != null)
                              ValueListenableBuilder<bool>(
                                valueListenable: exportNotifier!,
                                builder: (context, value, _) {
                                  return SwitchListTile(
                                    title: const Text(textExport),
                                    value: value,
                                    onChanged:
                                        (value) =>
                                            exportNotifier!.value = value,
                                  );
                                },
                              ),
                            if (publishDevNotifier != null)
                              ValueListenableBuilder<bool>(
                                valueListenable: publishDevNotifier!,
                                builder: (context, value, _) {
                                  return SwitchListTile(
                                    title: const Text(textPublishDev),
                                    value: value,
                                    onChanged:
                                        (value) =>
                                            publishDevNotifier!.value = value,
                                  );
                                },
                              ),
                            if (publishProdNotifier != null)
                              ValueListenableBuilder<bool>(
                                valueListenable: publishProdNotifier!,
                                builder: (context, value, _) {
                                  return SwitchListTile(
                                    title: const Text(textPublishProd),
                                    value: value,
                                    onChanged:
                                        (value) =>
                                            publishProdNotifier!.value = value,
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              LinearWait(showNotifier: saving),
            ],
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

  final _saveLock = Lock();

  Future<void> _onSave(BuildContext context) async {
    if (!_saveLock.locked) {
      await _saveLock.synchronized(() async {
        try {
          saving.value = true;
          if (formKey.currentState!.validate()) {
            var bloc = BlocProvider.of<AdminExportEditScreenBloc>(context);
            formKey.currentState!.save();
            var fsExport = bloc.state.value.fsExport!;
            //  ..name.v = _nameController!.text

            var data = AdminExportEditData(
              fsExport: fsExport,
              export: exportNotifier?.value == true,
              publish: publishProdNotifier?.value == true,
              publishDev: publishDevNotifier?.value == true,
            );
            await bloc.save(data);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
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
}

Future<void> goToAdminExportEditScreen(
  BuildContext context, {
  required FestenaoAdminAppProjectContext projectContext,
  required String? exportId,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) {
        return BlocProvider(
          blocBuilder:
              () => AdminExportEditScreenBloc(
                projectContext: projectContext,
                exportId: exportId,
              ),
          child: const AdminExportEditScreen(),
        );
      },
    ),
  );
}

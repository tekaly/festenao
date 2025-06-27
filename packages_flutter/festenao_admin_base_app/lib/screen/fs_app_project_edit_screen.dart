import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/unsaved_changes_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/busy_indicator.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

import '../sembast/projects_db.dart';
import 'fs_app_project_edit_screen_bloc.dart';

//import 'package:sqflite/src/utils.dart';
class FsAppProjectEditData {
  final String? projectId; // Null for creation with auto generation
  final FsProject project;

  FsAppProjectEditData({required this.projectId, required this.project});
}

class FsAppProjectEditScreen extends StatefulWidget {
  const FsAppProjectEditScreen({super.key});

  @override
  FsAppProjectEditScreenState createState() => FsAppProjectEditScreenState();
}

class FsAppProjectEditScreenState
    extends AutoDisposeBaseState<FsAppProjectEditScreen>
    with AutoDisposedBusyScreenStateMixin<FsAppProjectEditScreen> {
  final formKey = GlobalKey<FormState>();
  TextEditingController? _nameController;
  TextEditingController? _idController;

  bool _gotInitialProject = false;
  late FsProject initialProject;

  bool get _hasChanges {
    if (!_gotInitialProject) {
      return false;
    }
    var project = _projectFromInput;
    return (project.project.name.v?.trimmedNonEmpty() !=
        initialProject.name.v?.trimmedNonEmpty());
  }

  FsAppProjectEditData get _projectFromInput {
    var projectId = bloc.isCreate
        ? _idController?.text.trimmedNonEmpty()
        : bloc.projectId;
    var name = _nameController!.text.trimmedNonEmpty();
    var project = initialProject.clone();
    project.name.v = name;
    return FsAppProjectEditData(projectId: projectId, project: project);
  }

  bool _isEmptyProject(FsProject project) {
    return project.name.v?.trimmedNonEmpty() == null;
  }

  Future<void> _saveAndExit(BuildContext context) async {
    var project = _projectFromInput;
    if (_isEmptyProject(project.project)) {
      return;
    }
    var result = await busyAction(() async {
      var bloc = BlocProvider.of<FsAppProjectEditScreenBloc>(context);
      await bloc.saveProject(project);
    });
    if (!result.busy) {
      if (result.error == null) {
        if (context.mounted) {
          Navigator.pop(context);
        }
      } else {
        if (kDebugMode) {
          print('error ${result.errorStackTrace}');
        }
        if (context.mounted) {
          await muiSnack(context, 'error ${result.error}');
        }
      }
    }
  }

  FsAppProjectEditScreenBloc get bloc =>
      BlocProvider.of<FsAppProjectEditScreenBloc>(context);

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = this.bloc;

    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        if (state != null && !_gotInitialProject) {
          _gotInitialProject = true;
          initialProject = state.project ?? FsProject();
          _nameController = audiAddTextEditingController(
            TextEditingController(text: initialProject.name.v),
          );
          _idController = audiAddTextEditingController(
            TextEditingController(text: bloc.projectId),
          );
        }

        var hasChanges = _hasChanges;

        return PopScope(
          canPop: hasChanges,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }
            if (!_hasChanges) {
              Navigator.pop(context, result);
              return;
            }
            var dialogResult = await showUnsavedChangesDialog(context);
            if (dialogResult == UnsavedChangesDialogResult.save) {
              if (context.mounted) {
                await _saveAndExit(context);
              }
            } else if (dialogResult == UnsavedChangesDialogResult.discard) {
              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          },
          child: Scaffold(
            appBar: AppBar(
              // Here we take the value from the MyHomePage object that
              // was created by the App.build method, and use it to set
              // our appbar title.
              title: Text(intl.projectEditTitle),
            ),
            body: Stack(
              children: [
                Form(
                  key: formKey,
                  child: ListView(
                    children: <Widget>[
                      BodyContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            BodyHPadding(
                              child: TextFormField(
                                readOnly: !bloc.isCreate,
                                decoration: const InputDecoration(
                                  hintText: 'Project id',
                                  labelText: 'ID',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'ID required';
                                  }
                                  return null;
                                },
                                controller: _idController,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            BodyHPadding(
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  hintText: 'Project name',
                                  labelText: 'Name',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return intl.nameRequired;
                                  }
                                  return null;
                                },
                                controller: _nameController,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const SizedBox(height: 64),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                BusyIndicator(busy: busyStream),
              ],
            ),

            floatingActionButton: FloatingActionButton(
              //onPressed: _incrementCounter,
              //tooltip: 'Save',
              onPressed: _gotInitialProject
                  ? () async {
                      if (formKey.currentState!.validate()) {
                        await _saveAndExit(context);
                      }
                    }
                  : null,
              child: const Icon(Icons.save),
            ), // This trailing comma makes auto-formatting nicer for build methods.
          ),
        );
      },
    );
  }
}

Future<void> goToFsAppProjectEditScreen(
  BuildContext context, {
  required String? appId,
  required FsProject? project,
}) async {
  await festenaoPushScreen<void>(
    context,
    builder: (context) {
      return BlocProvider(
        blocBuilder: () =>
            FsAppProjectEditScreenBloc(project: project, appId: appId),
        child: const FsAppProjectEditScreen(),
      );
    },
  );
}

import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/view/unsaved_changes_dialog.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common_flutter/festenao_slug_flutter.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_edit_screen_bloc.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_slug_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/busy_indicator.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

//import 'package:sqflite/src/utils.dart';

class ProjectSdbEditScreen extends StatefulWidget {
  const ProjectSdbEditScreen({super.key});

  @override
  ProjectSdbEditScreenState createState() => ProjectSdbEditScreenState();
}

class ProjectSdbEditScreenState
    extends AutoDisposeBaseState<ProjectSdbEditScreen>
    with AutoDisposedBusyScreenStateMixin<ProjectSdbEditScreen> {
  final formKey = GlobalKey<FormState>();
  TextEditingController? _nameController;
  TextEditingController? _idController;
  TextEditingController? _slugController;
  String? _initialSlug;
  var _slugStatus = FestenaoSlugStatus.empty;

  bool _gotInitialProject = false;

  /// True when creating a new project (id can be specified).
  bool _isCreate = false;
  late SdbUserProject initialProject;

  bool get _hasChanges {
    if (!_gotInitialProject) {
      return false;
    }
    var project = _projectFromInput;
    if (project.name.v?.trimmedNonEmpty() !=
        initialProject.name.v?.trimmedNonEmpty()) {
      return true;
    }
    if (_isCreate && project.uid.v?.trimmedNonEmpty() != null) {
      return true;
    }
    if (_slugController!.text.trimmedNonEmpty() != _initialSlug) {
      return true;
    }
    return false;
  }

  SdbUserProject get _projectFromInput {
    var name = _nameController!.text.trimmedNonEmpty();
    var project = initialProject.clone();
    project.name.v = name;
    if (_isCreate) {
      project.uid.v = _idController!.text.trimmedNonEmpty();
    }
    return project;
  }

  bool _isEmptyNote(SdbUserProject project) {
    return project.name.v?.trimmedNonEmpty() == null;
  }

  Future<void> _saveAndExit(BuildContext context) async {
    var project = _projectFromInput;
    if (_isEmptyNote(project)) {
      return;
    }
    var slug = _slugController!.text.trimmedNonEmpty();
    if (slug != null && !_slugStatus.isAcceptable) {
      await muiSnack(context, 'Choose an available url');
      return;
    }
    var result = await busyAction(() async {
      var bloc = BlocProvider.of<ProjectEditScreenBloc>(context);
      await bloc.saveProject(project, slug: slug, currentSlug: _initialSlug);
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

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<ProjectEditScreenBloc>(context);

    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        if (state != null && !_gotInitialProject) {
          _gotInitialProject = true;
          _isCreate = bloc.isCreate;
          initialProject = state.project ?? SdbUserProject();
          _nameController = audiAddTextEditingController(
            TextEditingController(text: initialProject.name.v),
          );
          _idController = audiAddTextEditingController(
            TextEditingController(
              text: _isCreate ? null : initialProject.uid.v,
            ),
          );
          _initialSlug = state.slug;
          _slugController = audiAddTextEditingController(
            TextEditingController(text: _initialSlug),
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
                                decoration: InputDecoration(
                                  hintText: _isCreate
                                      ? 'Project id (optional)'
                                      : 'Project id',
                                  labelText: 'Id',
                                ),
                                readOnly: !_isCreate,
                                enabled: _isCreate,
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
                            if (_slugController != null)
                              BodyHPadding(
                                child: DashboardProjectSlugField(
                                  controller: _slugController!,
                                  projectId: _isCreate
                                      ? null
                                      : initialProject.fsId,
                                  currentSlug: _initialSlug,
                                  onStatusChanged: (status) =>
                                      _slugStatus = status,
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

Future<void> goToProjectEditScreen(
  BuildContext context, {
  required SdbUserProject? project,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) {
        return BlocProvider(
          blocBuilder: () => ProjectEditScreenBloc(project: project),
          child: const ProjectSdbEditScreen(),
        );
      },
    ),
  );
}

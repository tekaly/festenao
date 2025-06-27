import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/view/unsaved_changes_dialog.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/busy_indicator.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

import 'admin_app_scaffold.dart';
import 'fs_app_edit_screen_bloc.dart';

//import 'package:sqflite/src/utils.dart';
class FsAppEditScreenResult {
  final bool modified;

  FsAppEditScreenResult({required this.modified});

  @override
  String toString() => 'FsAppEditScreenResult(modified: $modified)';
}

class FsAppEditScreen extends StatefulWidget {
  const FsAppEditScreen({super.key});

  @override
  FsAppEditScreenState createState() => FsAppEditScreenState();
}

class FsAppEditScreenState extends AutoDisposeBaseState<FsAppEditScreen>
    with AutoDisposedBusyScreenStateMixin<FsAppEditScreen> {
  final formKey = GlobalKey<FormState>();
  TextEditingController? _nameController;
  TextEditingController? _idController; // New only

  bool _gotInitialApp = false;
  late TkCmsFsApp initialApp;

  bool get _hasChanges {
    if (!_gotInitialApp) {
      return false;
    }
    var app = _appFromInput.app;
    var appId = _appFromInput.appId;
    return (app.name.v?.trimmedNonEmpty() !=
            initialApp.name.v?.trimmedNonEmpty()) &&
        appId != initialApp.idOrNull;
  }

  FsAppEditData get _appFromInput {
    var name = _nameController!.text.trimmedNonEmpty();
    var id = _idController!.text.trim();
    var app = initialApp.clone();
    app.name.v = name;
    return FsAppEditData(appId: id, app: app);
  }

  bool _isEmptyApp(TkCmsFsApp app) {
    return app.name.v?.trimmedNonEmpty() == null;
  }

  Future<void> _saveAndExit(BuildContext context) async {
    var appEditData = _appFromInput;
    if (_isEmptyApp(appEditData.app)) {
      return;
    }
    var result = await busyAction(() async {
      var bloc = this.bloc;
      await bloc.saveApp(appEditData);
    });
    if (!result.busy) {
      if (result.error == null) {
        if (context.mounted) {
          Navigator.pop(context, FsAppEditScreenResult(modified: true));
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

  FsAppEditScreenBloc get bloc => BlocProvider.of<FsAppEditScreenBloc>(context);

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = this.bloc;

    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        if (state != null && !_gotInitialApp) {
          _gotInitialApp = true;
          initialApp = state.app ?? TkCmsFsApp();
          _nameController = audiAddTextEditingController(
            TextEditingController(text: initialApp.name.v),
          );
          _idController = audiAddTextEditingController(
            TextEditingController(text: bloc.param.appId),
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
          child: FestenaoAdminAppScaffold(
            appBar: AppBar(
              // Here we take the value from the MyHomePage object that
              // was created by the App.build method, and use it to set
              // our appbar title.
              title: Text('FsApp ${bloc.isCreate ? 'create' : 'edit'}'),
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
                                readOnly: bloc.param.appId != null,
                                decoration: const InputDecoration(
                                  hintText: 'App id',
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
                                  hintText: 'App name',
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
              onPressed: _gotInitialApp
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

Future<FsAppEditScreenResult?> goToFsAppEditScreen(
  BuildContext context, {

  /// null for new
  required String? appId,
}) async {
  var result = await Navigator.of(context).push(
    MaterialPageRoute<Object?>(
      builder: (context) {
        return BlocProvider(
          blocBuilder: () =>
              FsAppEditScreenBloc(param: FsAppEditScreenParam(appId: appId)),
          child: const FsAppEditScreen(),
        );
      },
    ),
  );
  if (result is FsAppEditScreenResult) {
    return result;
  }
  return null;
}

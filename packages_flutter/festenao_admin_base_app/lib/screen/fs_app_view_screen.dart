import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/fs_app_edit_screen.dart';

import 'package:festenao_common/festenao_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_user_app/theme/theme1.dart';
import 'package:tkcms_user_app/view/body_container.dart';

import 'fs_app_view_screen_bloc.dart';

class FsAppViewResult {
  final bool deleted;

  FsAppViewResult({required this.deleted});
}

class FsAppViewScreen extends StatefulWidget {
  const FsAppViewScreen({super.key});

  @override
  FsAppViewScreenState createState() => FsAppViewScreenState();
}

class FsAppViewScreenState extends AutoDisposeBaseState<FsAppViewScreen>
    with AutoDisposedBusyScreenStateMixin<FsAppViewScreen> {
  Future<void> _confirmAndDelete(BuildContext context, TkCmsFsApp app) async {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<FsAppViewScreenBloc>(context);
    var result = await busyAction(() async {
      if (await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Delete app'),
                content: Text('Confirm deletion of app ${app.name.v}'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(intl.cancelButtonLabel),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: Text(intl.deleteButtonLabel),
                  ),
                ],
              );
            },
          ) ==
          true) {
        await bloc.deleteApp(app);
        return true;
      } else {
        return false;
      }
    });
    if (!result.busy) {
      if (result.error != null) {
        if (context.mounted) {
          await muiSnack(context, result.error!.toString());
        }
      } else if (result.result == true) {
        if (context.mounted) {
          Navigator.pop(context, FsAppViewResult(deleted: true));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<FsAppViewScreenBloc>(context);

    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        var app = state?.app;

        var appName = app?.name.v ?? '<no name>';
        var canDelete = app != null;
        var canEdit = app != null;
        /*
          var noteDescription = note?.description.v;
          var noteContent = note?.content.v;*/

        var children = <Widget>[
          BodyHPadding(
            child: Text(
              appName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          if (app != null)
            ListTile(
              //leading: AppLeading(app: app),
              title: Text(appName),
              subtitle: Text(app.id),
            ),
        ];

        return Scaffold(
          appBar: AppBar(
            // Here we take the value from the MyHomePage object that
            // was created by the App.build method, and use it to set
            // our appbar title.
            title: Text(appName),
            actions:
                app == null
                    ? null
                    : <Widget>[
                      if (canDelete)
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await _confirmAndDelete(context, app);
                          },
                        ),
                    ],
          ),
          body:
              state == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                    children: [
                      BodyContainer(
                        child: BodyHPadding(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(),
                              ...children,
                              Center(
                                child: IntrinsicWidth(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ...[
                                        const SizedBox(height: 24),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: colorError,
                                          ),
                                          onPressed:
                                              canDelete
                                                  ? () {
                                                    _confirmAndDelete(
                                                      context,
                                                      app,
                                                    );
                                                  }
                                                  : null,
                                          child: const Text('Delete app'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 64),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

          //new Column(children: children),
          floatingActionButton:
              canEdit
                  ? FloatingActionButton(
                    //onPressed: _incrementCounter,
                    tooltip: 'Edit',
                    onPressed: () async {
                      await goToFsAppEditScreen(context, appId: app.id);
                    },
                    child: const Icon(Icons.edit),
                  )
                  : null, // This trailing comma makes auto-formatting nicer for build methods.
        );
      },
    );
  }
}

Future<Object?> goToAppViewScreen(
  BuildContext context, {
  required String appId,
}) {
  return Navigator.of(context).push(
    (MaterialPageRoute(
      builder:
          (_) => BlocProvider(
            blocBuilder: () => FsAppViewScreenBloc(appId: appId),
            child: const FsAppViewScreen(),
          ),
    )),
  );
}

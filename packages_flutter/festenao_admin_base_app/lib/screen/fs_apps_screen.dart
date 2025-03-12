import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';

import 'package:festenao_admin_base_app/screen/fs_app_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/with_header_footer_list_view.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

import 'fs_apps_screen_bloc.dart';

class FsAppsScreenSelectResult {
  final String app;

  FsAppsScreenSelectResult({required this.app});

  @override
  String toString() => 'FsAppsScreenSelectResult($app)';
}

/// Apps screen
class FsAppsScreen extends StatefulWidget {
  /// Apps screen
  const FsAppsScreen({super.key});

  @override
  State<FsAppsScreen> createState() => _FsAppsScreenState();
}

class _FsAppsScreenState extends State<FsAppsScreen> {
  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<FsAppsScreenBloc>(context);
    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        return FestenaoAdminAppScaffold(
          appBar: AppBar(
            title: const Text('Apps'), // appIntl(context).AppsTitle),
            /*actions: [
                IconButton(
                    onPressed: () {
                      ContentNavigator.of(context)
                          .pushPath<void>(SettingsContentPath());
                    },
                    icon: const Icon(Icons.settings)),
              ],*/
            // automaticallyImplyLeading: false,
          ),
          body: Builder(
            builder: (context) {
              if (state == null) {
                return const Center(child: CircularProgressIndicator());
              }
              var apps = state.apps;
              return WithHeaderFooterListView.builder(
                footer:
                    state.identity == null
                        ? const BodyContainer(
                          child: BodyHPadding(
                            child: Center(
                              child: Column(
                                children: [
                                  Text(
                                    'Not signed in',
                                  ), // appIntl(context).notSignedInInfo),
                                  SizedBox(height: 8),
                                  /*
                            ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              globalAuthFlutterUiService
                                                  .loginScreen(
                                                      firebaseAuth:
                                                          globalFirebaseContext
                                                              .auth)));
                                },
                                child:
                                    Text(appIntl(context).signInButtonLabel)),*/
                                ],
                              ),
                            ),
                          ),
                        )
                        : null,
                itemCount: apps.length,
                itemBuilder: (context, index) {
                  var app = apps[index];
                  return BodyContainer(
                    child: ListTile(
                      //leading: AppLeading(app: app),
                      //trailing: const TrailingArrow(),
                      /*Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                onPressed: () {
                                  //goToNotesScreen(context, App.ref);
                                  goToAppViewScreen(context,
                                      appRef: app.ref);
                                },
                                icon: const Icon(Icons.arrow_forward_ios)),
                            /*  IconButton(
                                onPressed: () {
                                  //_goToNotes(context, App.id);
                                },
                                icon: Icon(Icons.edit))*/
                          ],
                        ),*/
                      title: Text(app.name.v ?? app.id),
                      onTap: () async {
                        if (bloc.selectMode) {
                          Navigator.of(
                            context,
                          ).pop(FsAppsScreenSelectResult(app: app.id));
                        } else {
                          await goToAppViewScreen(context, appId: app.id);
                        }
                        //  await goToNotesScreen(context, App.ref);
                      },
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              //await goToAppEditScreen(context, app: null);
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

/// Go to Apps screen
Future<Object?> goToFsAppsScreen(BuildContext context) async {
  return Navigator.of(context).push(
    (MaterialPageRoute(
      builder:
          (_) => BlocProvider(
            blocBuilder: () => FsAppsScreenBloc(),
            child: const FsAppsScreen(),
          ),
    )),
  );
}

/// Go to Apps screen
Future<FsAppsScreenSelectResult?> selectFsApp(BuildContext context) async {
  var result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder:
          (_) => BlocProvider(
            blocBuilder: () => FsAppsScreenBloc(selectMode: true),
            child: const FsAppsScreen(),
          ),
    ),
  );
  if (result is FsAppsScreenSelectResult) {
    return result;
  }
  return null;
}

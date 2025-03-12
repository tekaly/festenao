import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_admin_base_app/screen/fs_app_edit_screen.dart';

import 'package:festenao_admin_base_app/screen/fs_app_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/with_header_footer_list_view.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

import 'fs_apps_screen_bloc.dart';

class FsAppsScreenSelectResult {
  final String appId;

  FsAppsScreenSelectResult({required this.appId});

  @override
  String toString() => 'FsAppsScreenSelectResult($appId)';
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
                      title: Text(app.name.v ?? app.id),
                      subtitle: Text(app.id),
                      onTap: () async {
                        if (bloc.selectMode) {
                          Navigator.of(
                            context,
                          ).pop(FsAppsScreenSelectResult(appId: app.id));
                        } else {
                          var result = await goToFsAppViewScreen(
                            context,
                            appId: app.id,
                          );
                          if (context.mounted && (result?.modified ?? false)) {
                            bloc.refresh();
                          }
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
              var result = await goToFsAppEditScreen(context, appId: null);
              if (mounted && (result?.modified ?? false)) {
                bloc.refresh();
              }
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

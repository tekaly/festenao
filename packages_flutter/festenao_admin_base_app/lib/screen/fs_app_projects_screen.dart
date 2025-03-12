import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_admin_base_app/screen/fs_app_project_view_screen.dart';
import 'package:festenao_admin_base_app/screen/projects_screen.dart';
import 'package:festenao_admin_base_app/view/not_signed_in_tile.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/with_header_footer_list_view.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

import 'fs_app_project_edit_screen.dart';
import 'fs_app_projects_screen_bloc.dart';
import 'projects_screen_bloc.dart';

/// Projects screen
class FsProjectsScreen extends StatefulWidget {
  /// Projects screen
  const FsProjectsScreen({super.key});

  @override
  State<FsProjectsScreen> createState() => _FsProjectsScreenState();
}

class _FsProjectsScreenState extends State<FsProjectsScreen> {
  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<FsAppProjectsScreenBloc>(context);
    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        return FestenaoAdminAppScaffold(
          appBar: AppBar(
            title: const Text('Project'), // appIntl(context).ProjectsTitle),
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
              var projects = state.projects;
              return WithHeaderFooterListView.builder(
                footer:
                    state.identity == null
                        ? const BodyContainer(
                          child: BodyHPadding(
                            child: Center(
                              child: Column(
                                children: [
                                  IdentityWarningTile(),
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
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  var project = projects[index];
                  return BodyContainer(
                    child: ListTile(
                      title: Text(project.name.v ?? project.id),
                      subtitle: Text(project.id),
                      onTap: () async {
                        if (bloc.selectMode) {
                          Navigator.of(
                            context,
                          ).pop(SelectProjectResult(projectId: project.id));
                        } else {
                          await goToFsAppProjectViewScreen(
                            context,
                            projectId: project.id,
                            appId: bloc.appId,
                          );
                        }
                        //  await goToNotesScreen(context, Project.ref);
                      },
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              await goToFsAppProjectEditScreen(
                context,
                project: null,
                appId: bloc.appId,
              );
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

/// Go to Projects screen
Future<Object?> goToFsAppProjectsScreen(
  BuildContext context, {
  String? appId,
}) async {
  return Navigator.of(context).push(
    (MaterialPageRoute(
      builder:
          (_) => BlocProvider(
            blocBuilder: () => FsAppProjectsScreenBloc(appId: appId),
            child: const FsProjectsScreen(),
          ),
    )),
  );
}

/// Go to Projects screen
Future<SelectProjectResult?> selectFsAppProject(BuildContext context) async {
  var result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder:
          (_) => BlocProvider(
            blocBuilder: () => ProjectsScreenBloc(selectMode: true),
            child: const FsProjectsScreen(),
          ),
    ),
  );
  if (result is SelectProjectResult) {
    return result;
  }
  return null;
}

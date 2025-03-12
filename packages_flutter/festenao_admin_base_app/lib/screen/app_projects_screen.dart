import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_admin_base_app/screen/project_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/project_view_screen.dart';
import 'package:festenao_admin_base_app/screen/projects_screen.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/with_header_footer_list_view.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

import 'app_projects_screen_bloc.dart';
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
    var bloc = BlocProvider.of<FsProjectsScreenBloc>(context);
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
                    state.user == null
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
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  var project = projects[index];
                  return BodyContainer(
                    child: ListTile(
                      //leading: ProjectLeading(project: project),
                      //trailing: const TrailingArrow(),
                      /*Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                onPressed: () {
                                  //goToNotesScreen(context, Project.ref);
                                  goToProjectViewScreen(context,
                                      projectRef: project.ref);
                                },
                                icon: const Icon(Icons.arrow_forward_ios)),
                            /*  IconButton(
                                onPressed: () {
                                  //_goToNotes(context, Project.id);
                                },
                                icon: Icon(Icons.edit))*/
                          ],
                        ),*/
                      title: Text(project.name.v ?? project.id),
                      onTap: () async {
                        if (bloc.selectMode) {
                          Navigator.of(
                            context,
                          ).pop(SelectProjectResult(projectId: project.id));
                        } else {
                          await goToProjectViewScreen(
                            context,
                            projectId: project.id,
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
              await goToProjectEditScreen(context, project: null);
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

/// Go to Projects screen
Future<Object?> goToFsProjectsScreen(BuildContext context) async {
  return Navigator.of(context).push(
    (MaterialPageRoute(
      builder:
          (_) => BlocProvider(
            blocBuilder: () => FsProjectsScreenBloc(),
            child: const FsProjectsScreen(),
          ),
    )),
  );
}

/// Go to Projects screen
Future<SelectProjectResult?> selectFsProject(BuildContext context) async {
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

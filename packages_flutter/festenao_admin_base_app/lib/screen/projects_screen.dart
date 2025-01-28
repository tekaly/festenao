import 'package:festenao_admin_base_app/screen/project_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/project_view_screen.dart';
import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:festenao_admin_base_app/view/project_leading.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/with_header_footer_list_view.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_admin_app/view/trailing_arrow.dart';

import 'projects_screen_bloc.dart';

/// Projects screen
class ProjectsScreen extends StatefulWidget {
  /// Projects screen
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<ProjectsScreenBloc>(context);
    return ValueStreamBuilder(
        stream: bloc.state,
        builder: (context, snapshot) {
          var state = snapshot.data;
          return Scaffold(
            appBar: AppBar(
                title: const Text('Project') // appIntl(context).ProjectsTitle),
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
            body: Builder(builder: (context) {
              if (state == null) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              var projects = state.projects;
              return WithHeaderFooterListView.builder(
                  footer: state.user == null
                      ? const BodyContainer(
                          child: BodyHPadding(
                              child: Center(
                                  child: Column(
                          children: [
                            Text(
                                'Not signed in'), // appIntl(context).notSignedInInfo),
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
                        ))))
                      : null,
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    var project = projects[index];
                    return BodyContainer(
                      child: ListTile(
                        leading: ProjectLeading(project: project),
                        trailing: const TrailingArrow(),
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
                        title: Text(project.name.v ?? project.uid.v ?? ''),
                        onTap: () async {
                          if (bloc.selectMode) {
                            Navigator.of(context).pop(
                                SelectProjectResult(projectRef: project.ref));
                          } else {
                            await goToProjectViewScreen(context,
                                projectRef: project.ref);
                          }
                          //  await goToNotesScreen(context, Project.ref);
                        },
                      ),
                    );
                  });
            }),
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                await goToProjectEditScreen(context, project: null);
              },
              child: const Icon(Icons.add),
            ),
          );
        });
  }
}

/// Go to Projects screen
Future<Object?> goToProjectsScreen(
  BuildContext context,
) async {
  return await Navigator.of(context).push<Object?>(MaterialPageRoute(
      builder: (_) => BlocProvider(
          blocBuilder: () => ProjectsScreenBloc(),
          child: const ProjectsScreen())));
}

class SelectProjectResult {
  final ProjectRef projectRef;

  SelectProjectResult({required this.projectRef});

  @override
  String toString() => 'SelectProjectResult{projectRef: $projectRef}';
}

/// Go to Projects screen
Future<SelectProjectResult?> selectProject(
  BuildContext context,
) async {
  var result = await Navigator.of(context).push<Object?>(MaterialPageRoute(
      builder: (_) => BlocProvider(
          blocBuilder: () => ProjectsScreenBloc(selectMode: true),
          child: const ProjectsScreen())));
  if (result is SelectProjectResult) {
    return result;
  }
  return null;
}

import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/utils/project_ui_utils.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_admin_app/l10n/app_intl.dart';
import 'package:tkcms_user_app/theme/theme1.dart';
import 'package:tkcms_user_app/view/body_container.dart';

import '../sembast/projects_db.dart';
import '../view/project_leading.dart';
import 'project_edit_screen.dart';
import 'project_view_screen_bloc.dart';

class ProjectViewResult {
  final bool deleted;

  ProjectViewResult({required this.deleted});
}

class ProjectViewScreen extends StatefulWidget {
  const ProjectViewScreen({super.key});

  @override
  ProjectViewScreenState createState() => ProjectViewScreenState();
}

class ProjectViewScreenState extends AutoDisposeBaseState<ProjectViewScreen>
    with AutoDisposedBusyScreenStateMixin<ProjectViewScreen> {
  Future<void> _confirmAndDelete(
      BuildContext context, DbProject project) async {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<ProjectViewScreenBloc>(context);
    var result = await busyAction(() async {
      if (await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text(intl.projectDelete),
                  content: Text(intl.projectDeleteConfirm),
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
                    )
                  ],
                );
              }) ==
          true) {
        await bloc.deleteProject(project);
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
          Navigator.pop(context, ProjectViewResult(deleted: true));
        }
      }
    }
  }

  Future<void> _confirmAndLeave(BuildContext context, DbProject project) async {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<ProjectViewScreenBloc>(context);
    var result = await busyAction(() async {
      if (await showDialog<bool>(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text(intl.projectLeave),
                  content: Text(intl.projectLeaveConfirm),
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
                      child: Text(intl.leaveButtonLabel),
                    )
                  ],
                );
              }) ==
          true) {
        await bloc.leaveProject(project);
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
          Navigator.pop(context, ProjectViewResult(deleted: true));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var intl = appIntl(context);
    var bloc = BlocProvider.of<ProjectViewScreenBloc>(context);

    return ValueStreamBuilder(
        stream: bloc.state,
        builder: (context, snapshot) {
          var state = snapshot.data;
          var project = state?.project;
          var canEdit = project?.isWrite ?? false;
          var canDelete = project?.isAdmin ?? false;
          var canLeave = project != null;
          var projectName = project?.name.v;
          /*
          var noteDescription = note?.description.v;
          var noteContent = note?.content.v;*/

          var children = <Widget>[
            BodyHPadding(
                child: Text(projectName ?? '',
                    style: Theme.of(context).textTheme.headlineSmall)),
            if (project != null)
              ListTile(
                leading: ProjectLeading(project: project),
                title: Text(intl.projectTypeSynced),
                subtitle: accessText(intl, project),
              ),
          ];

          return Scaffold(
            appBar: AppBar(
              // Here we take the value from the MyHomePage object that
              // was created by the App.build method, and use it to set
              // our appbar title.
              title: Text(projectName ?? ''),
              actions: project == null
                  ? null
                  : <Widget>[
                      /*
                      if (project.isRemote)
                        IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () async {
                              await goToProjectShareScreen(context,
                                  project: project);
                            }),*/
                      if (canDelete)
                        IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await _confirmAndDelete(context, project);
                            }),
                    ],
            ),
            body: project == null
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
                                        /*
                                        if (project.isRemote) ...[
                                          const SizedBox(height: 24),
                                          ElevatedButton(
                                              onPressed: () {
                                                goToProjectShareScreen(context,
                                                    project: project);
                                              },
                                              child: Text(intl.projectShare)),
                                        ],*/
                                        const SizedBox(height: 24),
                                        ElevatedButton(
                                            onPressed: () {
                                              Navigator.of(context)
                                                  .popUntilPath(
                                                      rootContentPath);
                                              /*
                                              ContentNavigator.of(context)
                                                  .transientPopAll();
                                              goToNotesScreen(
                                                  context, project.ref);*/
                                            },
                                            child: Text(intl.projectViewNotes)),
                                        if (canLeave)
                                          const SizedBox(height: 24),
                                        ElevatedButton(
                                            onPressed: () {
                                              _confirmAndLeave(
                                                  context, project);
                                            },
                                            child: Text(intl.projectLeave)),
                                        if (canDelete) ...[
                                          const SizedBox(height: 24),
                                          ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: colorError),
                                              onPressed: () {
                                                _confirmAndDelete(
                                                    context, project);
                                              },
                                              child: Text(intl.projectDelete)),
                                        ]
                                      ]),
                                ),
                              ),
                              const SizedBox(height: 64),
                            ]),
                      ))
                    ],
                  ),
            //new Column(children: children),

            floatingActionButton: canEdit
                ? FloatingActionButton(
                    //onPressed: _incrementCounter,
                    tooltip: 'Edit',
                    onPressed: () async {
                      await goToProjectEditScreen(context, project: project!);
                    },
                    child: const Icon(Icons.edit),
                  )
                : null, // This trailing comma makes auto-formatting nicer for build methods.
          );
        });
  }
}

Future<void> goToProjectViewScreen(BuildContext context,
    {required String projectId}) async {
  var cn = ContentNavigator.of(context);
  await cn
      .pushPath<void>(SyncedProjectContentPath()..project.value = projectId);
}

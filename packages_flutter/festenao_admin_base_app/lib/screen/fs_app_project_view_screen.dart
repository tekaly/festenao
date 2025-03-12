import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/utils/project_ui_utils.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_user_app/theme/theme1.dart';
import 'package:tkcms_user_app/view/body_container.dart';

import 'fs_app_project_edit_screen.dart';
import 'fs_app_project_view_screen_bloc.dart';
import 'fs_app_users_screen.dart';

class FsAppProjectViewResult {
  final bool deleted;

  FsAppProjectViewResult({required this.deleted});
}

class FsAppProjectViewScreen extends StatefulWidget {
  const FsAppProjectViewScreen({super.key});

  @override
  FsAppProjectViewScreenState createState() => FsAppProjectViewScreenState();
}

class FsAppProjectViewScreenState
    extends AutoDisposeBaseState<FsAppProjectViewScreen>
    with AutoDisposedBusyScreenStateMixin<FsAppProjectViewScreen> {
  Future<void> _confirmAndDelete(
    BuildContext context,
    FsProject project,
  ) async {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<FsAppProjectViewScreenBloc>(context);
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
                  ),
                ],
              );
            },
          ) ==
          true) {
        await bloc.deleteProject(project.id);
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
          Navigator.pop(context, FsAppProjectViewResult(deleted: true));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<FsAppProjectViewScreenBloc>(context);

    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        var fsProject = state?.fsProject;
        var fsProjectAccess = state?.fsUserAccess;
        var canEdit = fsProject != null;
        var canDelete = fsProject != null;
        //var canLeave = project != null;
        var projectName = fsProject?.name.v;
        /*
          var noteDescription = note?.description.v;
          var noteContent = note?.content.v;*/

        var children = <Widget>[
          BodyHPadding(
            child: Text(
              projectName ?? '',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          if (fsProject != null)
            ListTile(
              //leading: ProjectLeading(project: project),
              title: Text(fsProject.id),

              subtitle: accessText(
                intl,
                fsProjectAccess ?? TkCmsFsUserAccess(),
              ),
            ),

          if (fsProject != null) ...[
            ListTile(
              //leading: ProjectLeading(project: project),
              title: Text(projectName ?? ''),

              subtitle: accessText(
                intl,
                fsProjectAccess ?? TkCmsFsUserAccess(),
              ),
            ),
          ],
        ];

        return Scaffold(
          appBar: AppBar(
            // Here we take the value from the MyHomePage object that
            // was created by the App.build method, and use it to set
            // our appbar title.
            title: Text(projectName ?? ''),
            actions: <Widget>[
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
                    await _confirmAndDelete(context, fsProject);
                  },
                ),
            ],
          ),
          body:
              fsProject == null
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

                                      const SizedBox(height: 24),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: colorError,
                                        ),
                                        onPressed:
                                            (canDelete)
                                                ? () {
                                                  _confirmAndDelete(
                                                    context,
                                                    fsProject,
                                                  );
                                                }
                                                : null,
                                        child: Text(
                                          intl.projectDelete.toUpperCase(),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton(
                                        onPressed: () async {
                                          await goToFsAppUsersScreen(
                                            context,
                                            projectId: fsProject.id,
                                            appId: bloc.appId,
                                          );
                                        },
                                        child: Text(
                                          'Project users'.toUpperCase(),
                                        ),
                                      ),
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
                      await goToFsAppProjectEditScreen(
                        context,
                        project: fsProject,
                        appId: bloc.appId,
                      );
                    },
                    child: const Icon(Icons.edit),
                  )
                  : null, // This trailing comma makes auto-formatting nicer for build methods.
        );
      },
    );
  }
}

Future<void> goToFsAppProjectViewScreen(
  BuildContext context, {
  required String projectId,
  required String? appId,
}) async {
  await festenaoPushScreen<void>(
    context,
    builder: (context) {
      return BlocProvider(
        blocBuilder:
            () =>
                FsAppProjectViewScreenBloc(projectId: projectId, appId: appId),
        child: const FsAppProjectViewScreen(),
      );
    },
  );
}

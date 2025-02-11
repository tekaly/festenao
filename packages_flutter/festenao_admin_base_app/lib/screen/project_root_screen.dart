import 'package:festenao_admin_base_app/admin_app/admin_app_project_context.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_admin_base_app/screen/admin_artists_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_events_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_images_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_infos_screen.dart';
import 'package:festenao_admin_base_app/utils/project_ui_utils.dart';
import 'package:festenao_admin_base_app/view/entry_tile.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_admin_app/l10n/app_intl.dart';
import 'package:tkcms_user_app/view/body_container.dart';

import '../view/project_leading.dart';
import 'admin_metas_screen.dart';
import 'project_root_screen_bloc.dart';

class ProjectRootResult {
  final bool deleted;

  ProjectRootResult({required this.deleted});
}

class ProjectRootScreen extends StatefulWidget {
  const ProjectRootScreen({super.key});

  @override
  ProjectRootScreenState createState() => ProjectRootScreenState();
}

class ProjectRootScreenState extends AutoDisposeBaseState<ProjectRootScreen>
    with AutoDisposedBusyScreenStateMixin<ProjectRootScreen> {
  @override
  Widget build(BuildContext context) {
    var intl = appIntl(context);
    var bloc = BlocProvider.of<ProjectRootScreenBloc>(context);

    return ValueStreamBuilder(
        stream: bloc.state,
        builder: (context, snapshot) {
          var state = snapshot.data;
          var project = state?.project;
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

          return FestenaoAdminAppScaffold(
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
                              EntryTile(
                                label: 'Metas',
                                onTap: () {
                                  goToAdminMetasScreen(context,
                                      projectContext:
                                          ByProjectIdAdminAppProjectContext(
                                              projectId: bloc.projectId));
                                },
                              ),
                              EntryTile(
                                label: 'Infos',
                                onTap: () {
                                  goToAdminInfosScreen(context,
                                      projectContext: bloc.projectContext);
                                },
                              ),
                              EntryTile(
                                label: 'Artists',
                                onTap: () {
                                  goToAdminArtistsScreen(context,
                                      projectContext: bloc.projectContext);
                                },
                              ),
                              EntryTile(
                                label: 'Events',
                                onTap: () {
                                  goToAdminEventsScreen(context,
                                      projectContext: bloc.projectContext);
                                },
                              ),
                              EntryTile(
                                label: 'Images',
                                onTap: () {
                                  goToAdminImagesScreen(context,
                                      projectContext: bloc.projectContext);
                                },
                              ),
                              const SizedBox(height: 64),
                            ]),
                      ))
                    ],
                  ),
            //new Column(children: children),
          );
        });
  }
}

Future<void> goToProjectRootScreen(BuildContext context,
    {required String projectId}) async {
  var cn = ContentNavigator.of(context);
  await cn.pushPath<void>(
      RootSyncedProjectContentPath()..project.value = projectId);
}

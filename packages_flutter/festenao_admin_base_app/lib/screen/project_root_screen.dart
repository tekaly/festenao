import 'package:festenao_admin_base_app/form/form_questions_screen.dart';
import 'package:festenao_admin_base_app/form/fs_form_info.dart';
import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/admin_artists_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_events_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_images_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_infos_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_users_screen.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/utils/project_ui_utils.dart';
import 'package:festenao_admin_base_app/view/entry_tile.dart';
import 'package:festenao_admin_base_app/view/info_tile.dart';
import 'package:festenao_admin_base_app/view/not_signed_in_tile.dart';
import 'package:festenao_admin_base_app/view/tile_padding.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/busy_screen_state_mixin.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_admin_app/screen/doc_entities_screen.dart';
import 'package:tkcms_user_app/view/body_container.dart';

import '../view/project_leading.dart';
import 'admin_exports_screen.dart';
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
    var intl = festenaoAdminAppIntl(context);
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
            child: Text(
              projectName ?? '',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          if (project != null)
            ListTile(
              leading: ProjectLeading(project: project),
              title: Text(intl.projectTypeSynced),
              subtitle: accessText(intl, project),
            ),
          const IdentityInfoTile(),
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
          body: state == null
              ? (const Center(child: CircularProgressIndicator()))
              : ListView(
                  children: [
                    if (project == null)
                      BodyContainer(
                        child: Column(
                          children: [
                            const Row(),
                            ...children,
                            const InfoTile(label: 'no access'),
                          ],
                        ),
                      )
                    else
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
                                  goToAdminMetasScreen(
                                    context,
                                    projectContext:
                                        ByProjectIdAdminAppProjectContext(
                                          projectId: bloc.projectId,
                                        ),
                                  );
                                },
                              ),
                              EntryTile(
                                label: 'Infos',
                                onTap: () {
                                  goToAdminInfosScreen(
                                    context,
                                    projectContext: bloc.projectContext,
                                  );
                                },
                              ),
                              EntryTile(
                                label: 'Artists',
                                onTap: () {
                                  goToAdminArtistsScreen(
                                    context,
                                    projectContext: bloc.projectContext,
                                  );
                                },
                              ),
                              EntryTile(
                                label: 'Events',
                                onTap: () {
                                  goToAdminEventsScreen(
                                    context,
                                    projectContext: bloc.projectContext,
                                  );
                                },
                              ),
                              EntryTile(
                                label: 'Images',
                                onTap: () {
                                  goToAdminImagesScreen(
                                    context,
                                    projectContext: bloc.projectContext,
                                  );
                                },
                              ),
                              EntryTile(
                                label: 'Publish',
                                onTap: () async {
                                  await goToAdminExportsScreen(
                                    context,
                                    projectContext: bloc.projectContext,
                                  );
                                },
                              ),
                              EntryTile(
                                label: 'Users',
                                onTap: () async {
                                  await goToAdminUsersScreen(
                                    context,
                                    projectId: bloc.projectId,
                                  );
                                },
                              ),
                              const TilePadding(child: Divider()),
                              EntryTile(
                                label: 'Sync (single)',
                                onTap: () async {
                                  await bloc.sync();
                                },
                              ),
                              const TilePadding(child: Divider()),
                              EntryTile(
                                label: 'Questions',
                                onTap: () async {
                                  await goToAdminFormQuestionsScreen(
                                    context,
                                    entityAccess: fbFsDocFormQuestionAccess(
                                      bloc
                                          .projectContext
                                          .firestoreDatabaseContext,
                                    ),
                                  );
                                },
                              ),
                              EntryTile(
                                label: 'Questions (raw doc)',
                                onTap: () async {
                                  await goToDocEntitiesScreen(
                                    context,
                                    entityAccess: fbFsDocFormQuestionAccess(
                                      bloc
                                          .projectContext
                                          .firestoreDatabaseContext,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 64),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
          //new Column(children: children),
        );
      },
    );
  }
}

Future<void> goToProjectRootScreen(
  BuildContext context, {
  required String projectId,
}) async {
  var cn = ContentNavigator.of(context);
  await cn.pushPath<void>(
    RootSyncedProjectContentPath()..project.value = projectId,
  );
}

Future<void> popAndGoToProjectRootScreen(
  BuildContext context, {
  required FestenaoAdminAppProjectContext projectContext,
}) async {
  var cn = ContentNavigator.of(context);
  cn.popUntilPathOrPush(
    context,
    AdminAppRootProjectContextPath()..project.value = projectContext.projectId,
  );
}

Future<void> popAndGoToProjectSubScreen(
  BuildContext context, {
  required FestenaoAdminAppProjectContext projectContext,
  required AdminAppRootProjectContextPath contentPath,
  TransitionDelegate? transitionDelegate,
}) async {
  var projectId = projectContext.projectId;
  var cn = ContentNavigator.of(context);
  final routeName = Navigator.of(context).widget.pages.last.name;
  //print('routeName: $routeName');
  //print('going to $contentPath');
  if (routeName != null && contentPath.matchesString(routeName)) {
    // print('Already in $contentPath');
    return;
  }
  var nextContentPath = contentPath..project.value = projectId;
  /*
  cn.popUntilPathOrPush(
      context, AdminAppRootProjectContextPath()..project.value = projectId);

  await sleep(300);
  await cn.pushPath<void>(contentPath..project.value = projectContext.projectId,
      transitionDelegate: const NoAnimationTransitionDelegate());*/
  cn.popUntilPathOrPush(
    context,
    nextContentPath,
    transitionDelegate: transitionDelegate,
  );
}

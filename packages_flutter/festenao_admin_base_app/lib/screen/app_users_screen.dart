import 'package:festenao_admin_base_app/route/navigator_def.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_admin_base_app/screen/app_user_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/app_users_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/project_view_screen.dart';
import 'package:festenao_admin_base_app/screen/projects_screen.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/with_header_footer_list_view.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

import 'app_user_edit_screen_bloc.dart';
import 'projects_screen_bloc.dart';

/// Projects screen
class FsAppUsersScreen extends StatefulWidget {
  /// Projects screen
  const FsAppUsersScreen({super.key});

  @override
  State<FsAppUsersScreen> createState() => _FsAppUsersScreenState();
}

class _FsAppUsersScreenState extends State<FsAppUsersScreen> {
  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<FsAppUsersScreenBloc>(context);
    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        var userId = state?.user?.uid;
        return FestenaoAdminAppScaffold(
          appBar: AppBar(
            title: const Text('Users'), // appIntl(context).ProjectsTitle),
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
                      title: Text(project.id),
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
          floatingActionButton:
              (userId != null)
                  ? FloatingActionButton(
                    onPressed: () async {
                      await goToAppUserEditScreen(
                        context,
                        param: AppUserEditScreenParam(userId: userId),
                      );
                    },
                    child: const Icon(Icons.add),
                  )
                  : null,
        );
      },
    );
  }
}

/// Go to Projects screen
Future<Object?> goToFsAppUsersScreen(BuildContext context) async {
  return ContentNavigator.of(context).pushPath(AppUsersContentPath());
}

/// Go to Projects screen
Future<SelectProjectResult?> selectFsProject(BuildContext context) async {
  var result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder:
          (_) => BlocProvider(
            blocBuilder: () => ProjectsScreenBloc(selectMode: true),
            child: const FsAppUsersScreen(),
          ),
    ),
  );
  if (result is SelectProjectResult) {
    return result;
  }
  return null;
}

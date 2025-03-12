import 'package:festenao_admin_base_app/admin_app/menu.dart';
import 'package:festenao_admin_base_app/auth/auth.dart';
import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/screen/fs_app_projects_screen.dart';
import 'package:festenao_admin_base_app/screen/fs_apps_screen.dart';

import 'package:festenao_admin_base_app/screen/project_root_screen.dart';
import 'package:festenao_admin_base_app/screen/projects_screen.dart';
import 'package:festenao_admin_base_app/view/not_signed_in_tile.dart';
import 'package:festenao_admin_base_app/view/project_leading.dart';
import 'package:festenao_admin_base_app/view/tile_padding.dart';
import 'package:flutter/foundation.dart';
import 'package:tekartik_app_flutter_widget/app_widget.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_admin_app/view/body_container.dart';
import 'package:tkcms_admin_app/view/body_h_padding.dart';
import 'package:tkcms_admin_app/view/go_to_tile.dart';
import 'package:tkcms_admin_app/view/trailing_arrow.dart';
import 'package:tkcms_common/tkcms_auth.dart';

import 'screen_import.dart';
import 'start_screen_bloc.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends AutoDisposeBaseState<StartScreen> {
  var hasAdminCredentials =
      globalFestenaoAdminAppFirebaseContext.firebaseApp.hasAdminCredentials;

  StartScreenBloc get bloc => BlocProvider.of<StartScreenBloc>(context);
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        // print('hasAdminCredentials: $hasAdminCredentials');
        return FestenaoAdminAppScaffold(
          appBar: AppBar(
            title: const Text('Festenao'), // appIntl(context).ProjectsTitle),
            actions: [
              if (!hasAdminCredentials)
                IconButton(
                  onPressed: () {
                    goToAuthScreen(context);
                  },
                  icon: const Icon(Icons.person),
                ),
            ],
            // automaticallyImplyLeading: false,
          ),
          body: Builder(
            builder: (context) {
              if (state == null) {
                return const Center(child: CircularProgressIndicator());
              }
              var projects = state.projects;
              var identity = state.identity;
              return WithHeaderFooterListView.builder(
                footer: BodyContainer(
                  child: Column(
                    children: [
                      if (identity == null)
                        const BodyContainer(
                          child: BodyHPadding(
                            child: Center(
                              child: Column(
                                children: [
                                  IdentityInfoTile(), // appIntl(context).notSignedInInfo),
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
                      else ...[
                        const IdentityInfoTile(),
                        const SizedBox(height: 32),

                        if (identity is TkCmsFbIdentityUser)
                          GoToTile(
                            titleLabel: 'All projects',
                            onTap: () {
                              goToProjectsScreen(context);
                            },
                          ),
                      ],
                      const TilePadding(child: Divider()),
                      if (hasAdminCredentials) ...[
                        GoToTile(
                          titleLabel:
                              'FsApps (default ${globalFestenaoFirestoreDatabase.appId})',
                          onTap: () {
                            goToFsAppsScreen(context);
                          },
                        ),
                        GoToTile(
                          titleLabel: 'FsProjects',
                          onTap: () {
                            goToFsAppProjectsScreen(context);
                          },
                        ),
                        GoToTile(
                          titleLabel: 'FsUsers',
                          onTap: () {
                            goToFsAppProjectsScreen(context);
                          },
                        ),
                      ],
                      if (kDebugMode) ...[
                        const SizedBox(height: 64),
                        GoToTile(
                          titleLabel: 'Debug',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => festenaoAdminDebugScreen,
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                itemCount: projects?.length ?? 0,
                itemBuilder: (context, index) {
                  var project = projects![index];
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
                      title: Text(project.name.v ?? project.fsId),
                      onTap: () async {
                        await goToProjectRootScreen(
                          context,
                          projectId: project.fsId,
                        );

                        //  await goToNotesScreen(context, Project.ref);
                      },
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

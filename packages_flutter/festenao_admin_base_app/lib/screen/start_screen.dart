import 'package:festenao_admin_base_app/admin_app/menu.dart';
import 'package:festenao_admin_base_app/auth/auth.dart';

import 'package:festenao_admin_base_app/screen/project_root_screen.dart';
import 'package:festenao_admin_base_app/screen/projects_screen.dart';
import 'package:festenao_admin_base_app/view/entry_tile.dart';
import 'package:festenao_admin_base_app/view/project_leading.dart';
import 'package:flutter/foundation.dart';
import 'package:tekartik_app_flutter_widget/app_widget.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_admin_app/view/body_container.dart';
import 'package:tkcms_admin_app/view/body_h_padding.dart';
import 'package:tkcms_admin_app/view/trailing_arrow.dart';

import 'screen_import.dart';
import 'start_screen_bloc.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends AutoDisposeBaseState<StartScreen> {
  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<StartScreenBloc>(context);
    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;
        return FestenaoAdminAppScaffold(
          appBar: AppBar(
            title: const Text('Festenao'), // appIntl(context).ProjectsTitle),
            actions: [
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
              return WithHeaderFooterListView.builder(
                footer: BodyContainer(
                  child: Column(
                    children: [
                      if (state.user == null)
                        const BodyContainer(
                          child: BodyHPadding(
                            child: Center(
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text('Not signed in'),
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
                      else
                        EntryTile(
                          label: 'All projects',
                          onTap: () {
                            goToProjectsScreen(context);
                          },
                        ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 64),
                        ListTile(
                          title: const Text('Debug'),
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

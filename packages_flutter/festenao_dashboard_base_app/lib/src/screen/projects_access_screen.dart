import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_leading.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_edit_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/projects_sdb_screen_bloc.dart';
import 'package:festenao_dashboard_base_app/src/provider/auth_rpd.dart';
import 'package:festenao_dashboard_base_app/src/provider/festenao_user_projects.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_access_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/with_header_footer_list_view.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_admin_app/view/trailing_arrow.dart';

/// Projects screen
class DashboardProjectsAccessScreen extends ConsumerStatefulWidget {
  static const routeName = 'projects_access';

  /// Projects screen
  const DashboardProjectsAccessScreen({super.key});

  static const routeLocation = '/projects_access';

  @override
  ConsumerState<DashboardProjectsAccessScreen> createState() =>
      _ProjectsScreenState();
}

class _ProjectsScreenState
    extends ConsumerState<DashboardProjectsAccessScreen> {
  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<ProjectsSdbScreenBloc>(context);
    var auth = ref.watch(rpdTkCmsFbIdentityBlocStateProvider);

    return auth.when(
      data: (data) {
        return ValueStreamBuilder(
          stream: bloc.state,
          builder: (context, snapshot) {
            var state = snapshot.data;
            return FestenaoAdminAppScaffold(
              appBar: AppBar(
                title: const Text(
                  'Dashboard Projects prv sdb',
                ), // appIntl(context).ProjectsTitle),
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
                    footer: state.identity == null
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
                            if (bloc.selectMode) {
                              Navigator.of(context).pop(
                                SelectProjectResult(projectId: project.fsId),
                              );
                            } else {
                              var projectId = project.fsId;

                              context.push(
                                DashboardProjectAccessScreen.location(
                                  projectId,
                                ),
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
      },
      error: (Object error, StackTrace stackTrace) {
        return Text('error: $error');
      },
      loading: () {
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

/// Go to Projects screen
Future<Object?> goToProjectsScreen(BuildContext context) async {
  return await ContentNavigator.of(
    context,
  ).pushPath<Object?>(ProjectsContentPath());
  /*<Object?>(MaterialPageRoute(
      builder: (_) => BlocProvider(
          blocBuilder: () => ProjectsScreenBloc(),
          child: const ProjectsScreen())));*/
}

class SelectProjectResult {
  final String projectId;

  SelectProjectResult({required this.projectId});

  @override
  String toString() => 'SelectProjectResult{projectRef: $projectId}';
}

/// Go to Projects screen
Future<SelectProjectResult?> selectProject(
  Ref ref,
  BuildContext context,
) async {
  var projectsDb = ref.watch(rpdUserProjectsDbProvider);
  var result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder: (_) => BlocProvider(
        blocBuilder: () =>
            ProjectsSdbScreenBloc(selectMode: true, projectsDb: projectsDb),
        child: const DashboardProjectsAccessScreen(),
      ),
    ),
  );
  if (result is SelectProjectResult) {
    return result;
  }
  return null;
}

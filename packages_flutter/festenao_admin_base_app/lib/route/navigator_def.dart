import 'package:festenao_admin_base_app/admin_app/admin_app_project_context.dart';
import 'package:festenao_admin_base_app/screen/admin_artist_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_artists_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_event_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_events_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_export_view_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_exports_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_exports_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/admin_image_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_images_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_info_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_infos_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_metas_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/project_view_screen.dart';
import 'package:festenao_admin_base_app/screen/project_view_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/projects_screen.dart';
import 'package:festenao_admin_base_app/screen/projects_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/start_screen.dart';
import 'package:festenao_admin_base_app/screen/start_screen_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:tekartik_app_flutter_bloc/bloc_provider.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';

import 'route_paths.dart';

export 'package:tekartik_app_navigator_flutter/content_navigator.dart';

/// Root/Start screen builder
Widget festenaoAdminAppUserRootScreenBuilder(ContentPathRouteSettings crps) {
  return BlocProvider(
      blocBuilder: () => StartScreenBloc(), child: const StartScreen());
}

var userRootPageDef = festenaoAdminAppStartPagePageDef;
var festenaoAdminAppStartPagePageDef = ContentPageDef(
    screenBuilder: festenaoAdminAppUserRootScreenBuilder,
    path: rootContentPath);
var homeRootPageDef = ContentPageDef(
    screenBuilder: festenaoAdminAppUserRootScreenBuilder,
    path: HomeContentPath());
var projectsPageDef = ContentPageDef(
    screenBuilder: (crps) {
      return BlocProvider(
          blocBuilder: () => ProjectsScreenBloc(),
          child: const ProjectsScreen());
    },
    path: ProjectsContentPath());
/*
var settingsPageDef = ContentPageDef(
    screenBuilder: (crps) {
      return BlocProvider(
          blocBuilder: () => SettingsScreenBloc(),
          child: const SettingsScreen());
    },
    path: SettingsContentPath());

var settingProjectsPageDef = ContentPageDef(
    screenBuilder: (crps) {
      return BlocProvider(
          blocBuilder: () => ProjectsScreenBloc(),
          child: const SettingProjectsScreen());
    },
    path: SettingProjectsContentPath());
var markdownGuidePageDef = ContentPageDef(
    path: MarkdownGuideContentPath(),
    screenBuilder: (crps) {
      return const MarkdownGuideScreen();
    });
var projectPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = LocalProjectContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      return BlocProvider(
          blocBuilder: () =>
              ProjectViewScreenBloc(projectRef: ProjectRef(id: projectId)),
          child: const ProjectViewScreen());
    },
    path: LocalProjectContentPath());

var projectInvitePageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = ProjectInviteContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      var inviteId = cp.invite.value!;
      return BlocProvider(
          blocBuilder: () => ProjectInviteViewScreenBloc(
              projectId: projectId, inviteId: inviteId),
          child: const ProjectInviteViewScreen());
    },
    path: ProjectInviteContentPath());*/
var adminViewSyncedProjectPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = SyncedProjectContentPath()..fromPath(crps.path);
      var syncedProjectId = cp.project.value!;
      return BlocProvider(
          blocBuilder: () => ProjectViewScreenBloc(projectId: syncedProjectId),
          child: const ProjectViewScreen());
    },
    path: SyncedProjectContentPath());

var rootSyncedProjectPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = RootSyncedProjectContentPath()..fromPath(crps.path);
      var syncedProjectId = cp.project.value!;
      return BlocProvider(
          blocBuilder: () => ProjectRootScreenBloc(projectId: syncedProjectId),
          child: const ProjectRootScreen());
    },
    path: RootSyncedProjectContentPath());

var projectMetasPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = ProjectMetasContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      var projectContext =
          ByProjectIdAdminAppProjectContext(projectId: projectId);
      return BlocProvider(
          blocBuilder: () =>
              AdminMetasScreenBloc(projectContext: projectContext),
          child: const AdminMetasScreen());
    },
    path: ProjectMetasContentPath());

var projectInfosPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = ProjectInfosContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      var projectContext =
          ByProjectIdAdminAppProjectContext(projectId: projectId);
      return BlocProvider(
          blocBuilder: () =>
              AdminInfosScreenBloc(projectContext: projectContext),
          child: const AdminInfosScreen());
    },
    path: ProjectInfosContentPath());

var projectInfoPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = ProjectInfoContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      var subId = cp.sub.value!;
      var projectContext =
          ByProjectIdAdminAppProjectContext(projectId: projectId);
      return BlocProvider(
          blocBuilder: () => AdminInfoScreenBloc(
              projectContext: projectContext, infoId: subId),
          child: const AdminInfoScreen());
    },
    path: ProjectInfoContentPath());

var projectArtistsPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = ProjectArtistsContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      var projectContext =
          ByProjectIdAdminAppProjectContext(projectId: projectId);
      return BlocProvider(
          blocBuilder: () =>
              AdminArtistsScreenBloc(projectContext: projectContext),
          child: const AdminArtistsScreen());
    },
    path: ProjectArtistsContentPath());

var projectArtistPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = ProjectArtistContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      var subId = cp.sub.value!;
      var projectContext =
          ByProjectIdAdminAppProjectContext(projectId: projectId);
      return BlocProvider(
          blocBuilder: () => AdminArtistScreenBloc(
              projectContext: projectContext, artistId: subId),
          child: const AdminArtistScreen());
    },
    path: ProjectArtistContentPath());
var projectImagesPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = ProjectImagesContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      var projectContext =
          ByProjectIdAdminAppProjectContext(projectId: projectId);
      return BlocProvider(
          blocBuilder: () =>
              AdminImagesScreenBloc(projectContext: projectContext),
          child: const AdminImagesScreen());
    },
    path: ProjectImagesContentPath());

var projectImagePageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = ProjectImageContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      var subId = cp.sub.value!;
      var projectContext =
          ByProjectIdAdminAppProjectContext(projectId: projectId);
      return BlocProvider(
          blocBuilder: () => AdminImageScreenBloc(
              projectContext: projectContext, imageId: subId),
          child: const AdminImageScreen());
    },
    path: ProjectImageContentPath());
var projectEventsPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = ProjectEventsContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      var projectContext =
          ByProjectIdAdminAppProjectContext(projectId: projectId);
      return BlocProvider(
          blocBuilder: () =>
              AdminEventsScreenBloc(projectContext: projectContext),
          child: const AdminEventsScreen());
    },
    path: ProjectEventsContentPath());

var projectEventPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = ProjectEventContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      var subId = cp.sub.value!;
      var projectContext =
          ByProjectIdAdminAppProjectContext(projectId: projectId);
      return BlocProvider(
          blocBuilder: () => AdminEventScreenBloc(
              projectContext: projectContext, eventId: subId),
          child: const AdminEventScreen());
    },
    path: ProjectEventContentPath());

var projectExportsPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = ProjectExportsContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      var projectContext =
          ByProjectIdAdminAppProjectContext(projectId: projectId);
      return BlocProvider(
          blocBuilder: () =>
              AdminExportsScreenBloc(projectContext: projectContext),
          child: const AdminExportsScreen());
    },
    path: ProjectExportsContentPath());

var projectExportPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = ProjectExportContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      var subId = cp.sub.value!;
      var projectContext =
          ByProjectIdAdminAppProjectContext(projectId: projectId);
      return BlocProvider(
          blocBuilder: () => AdminExportViewScreenBloc(
              projectContext: projectContext, exportId: subId),
          child: const AdminExportViewScreen());
    },
    path: ProjectExportContentPath());
/*
var syncedProjectNotesPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = SyncedProjectNotesContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      return BlocProvider(
          blocBuilder: () =>
              NotesScreenBloc(projectRef: ProjectRef(syncedId: projectId)),
          child: const NotesScreen());
    },
    path: SyncedProjectNotesContentPath());
var projectNoteViewPageDef = ContentPageDef(
    path: LocalProjectNoteContentPath(),
    screenBuilder: (crps) {
      var cp = LocalProjectNoteContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      var noteId = cp.note.value!;
      var note = crps.arguments?.anyAs<DbNote?>();

      return BlocProvider(
          blocBuilder: () => NoteViewScreenBloc(
              projectRef: ProjectRef(id: projectId),
              noteId: noteId,
              note: note),
          child: const NoteViewScreen());
    });
var syncedProjectNoteViewPageDef = ContentPageDef(
    path: SyncedProjectNoteContentPath(),
    screenBuilder: (crps) {
      var cp = SyncedProjectNoteContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      var noteId = cp.note.value!;
      var note = crps.arguments?.anyAs<DbNote?>();

      return BlocProvider(
          blocBuilder: () => NoteViewScreenBloc(
              projectRef: ProjectRef(syncedId: projectId),
              noteId: noteId,
              note: note),
          child: const NoteViewScreen());
    });
*/

final festenaoAdminAppPages = [
  // start
  userRootPageDef,
  homeRootPageDef,
  projectsPageDef,
  projectMetasPageDef,
  projectInfosPageDef,
  projectInfoPageDef,
  projectArtistsPageDef,
  projectArtistPageDef,
  projectImagesPageDef,
  projectImagePageDef,
  projectEventsPageDef,
  projectEventPageDef,
  projectExportsPageDef,
  projectExportPageDef,
  /*
  settingsPageDef,
  settingProjectsPageDef,
  projectPageDef,*/
  rootSyncedProjectPageDef,
  adminViewSyncedProjectPageDef, /*
  projectNotesPageDef,
  syncedProjectNotesPageDef,
  projectNoteViewPageDef,
  syncedProjectNoteViewPageDef,
  projectInvitePageDef,
  markdownGuidePageDef,*/
];
final contentNavigatorDef = ContentNavigatorDef(defs: [
  ...festenaoAdminAppPages,
]);

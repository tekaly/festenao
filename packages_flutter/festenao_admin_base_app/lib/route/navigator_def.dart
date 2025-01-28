import 'package:festenao_admin_base_app/admin_app/menu.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/project_view_screen.dart';
import 'package:festenao_admin_base_app/screen/project_view_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/projects_screen.dart';
import 'package:festenao_admin_base_app/screen/projects_screen_bloc.dart';
import 'package:tekartik_app_flutter_bloc/bloc_provider.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';

import '../sembast/projects_db.dart';
import 'route_paths.dart';

var userRootPageDef = ContentPageDef(
    screenBuilder: (crps) {
      return festenaoAdminDebugScreen;
      /*
      return BlocProvider(
          blocBuilder: () => StartScreenBloc(),
          child: StartScreen(
            contentPath: rootContentPath,
          ));*/
    },
    path: rootContentPath);

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
          blocBuilder: () => ProjectViewScreenBloc(
              projectRef: ProjectRef(syncedId: syncedProjectId)),
          child: const ProjectViewScreen());
    },
    path: SyncedProjectContentPath());

var rootSyncedProjectPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = SyncedProjectContentPath()..fromPath(crps.path);
      var syncedProjectId = cp.project.value!;
      return BlocProvider(
          blocBuilder: () => ProjectRootScreenBloc(
              projectRef: ProjectRef(syncedId: syncedProjectId)),
          child: const ProjectRootScreen());
    },
    path: RootSyncedProjectContentPath());
/*
var projectNotesPageDef = ContentPageDef(
    screenBuilder: (crps) {
      var cp = LocalProjectNotesContentPath()..fromPath(crps.path);
      var projectId = cp.project.value!;
      return BlocProvider(
          blocBuilder: () =>
              NotesScreenBloc(projectRef: ProjectRef(id: projectId)),
          child: const NotesScreen());
    },
    path: LocalProjectNotesContentPath());
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
final contentNavigatorDef = ContentNavigatorDef(defs: [
  userRootPageDef,
  projectsPageDef,
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
]);

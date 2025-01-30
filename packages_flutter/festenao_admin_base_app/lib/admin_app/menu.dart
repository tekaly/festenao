import 'package:festenao_admin_base_app/auth/auth.dart';
import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/prefs/local_prefs.dart';
import 'package:festenao_admin_base_app/screen/fs_entity_list_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen.dart';
import 'package:festenao_admin_base_app/screen/projects_screen.dart';
import 'package:tekaly_firestore_explorer/firestore_explorer.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tkcms_admin_app/screen/debug_screen.dart';

/// Festenao admin menu
final festenaoAdminDebugScreen = muiScreenWidget('Festenao debug', () {
  muiItem('Auth', () {
    goToAuthScreen(muiBuildContext);
  });
  muiItem('Entity', () {
    goToFsEntityListScreen(muiBuildContext);
  });
  muiItem('TKCms Debug', () {
    goToAdminDebugScreen(muiBuildContext);
  });
  muiItem('Projects', () {
    goToProjectsScreen(muiBuildContext);
  });
  muiItem('Select Project', () async {
    var result = await selectProject(muiBuildContext);
    if (muiBuildContext.mounted) {
      var projectId = result?.projectId;
      if (projectId != null) {
        globalPrefs.currentProjectId = projectId;
      }
      await muiSnack(muiBuildContext, 'result: $result');
    }
  });
  muiItem('Go to current project', () async {
    var currentProjectId = globalPrefs.currentProjectId;
    if (currentProjectId == null) {
      await muiSnack(muiBuildContext, 'No current project');
      return;
    } else {
      await goToProjectRootScreen(muiBuildContext, projectId: currentProjectId);
    }
  });
  muiItem('Firestore explorer', () async {
    await goToFsDocumentRootScreen(muiBuildContext,
        firestore: globalAdminAppFirebaseContext.firestore);
  });
});

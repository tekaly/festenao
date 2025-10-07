import 'package:festenao_admin_base_app/auth/auth.dart';
import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/form/form_questions_screen.dart';
import 'package:festenao_admin_base_app/form/fs_form_info.dart';
import 'package:festenao_admin_base_app/prefs/local_prefs.dart';
import 'package:festenao_admin_base_app/screen/fs_app_projects_screen.dart';
import 'package:festenao_admin_base_app/screen/fs_app_users_screen.dart';
import 'package:festenao_admin_base_app/screen/fs_app_view_screen.dart';
import 'package:festenao_admin_base_app/screen/fs_apps_screen.dart';
import 'package:festenao_admin_base_app/screen/fs_entity_list_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_users_screen.dart';
import 'package:festenao_admin_base_app/screen/projects_screen.dart';
import 'package:festenao_common/sembast/projects_db.dart';
import 'package:tekaly_firestore_explorer/firestore_explorer.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tkcms_admin_app/firebase/database_service.dart';
import 'package:tkcms_admin_app/screen/basic_entities_screen.dart';
import 'package:tkcms_admin_app/screen/debug_screen.dart';
import 'package:tkcms_admin_app/screen/doc_entities_screen.dart';

/// Default debug menu
var festenaoAdminDebugScreen = festenaoAdminDebugScreenDefault;

/// Festenao admin menu
final festenaoAdminDebugScreenDefault = muiScreenWidget('Festenao debug', () {
  muiMenu('Global admin', () {
    muiItem('Users', () async {
      await goToAdminUsersScreen(muiBuildContext, projectId: 'app');
    });
  });
  muiMenu('Projects db', () {
    muiItem('Clear local projects db', () async {
      await globalProjectsDb.clear();
    });
  });
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
  muiItem('Questions', () async {
    await goToAdminFormQuestionsScreen(
      muiBuildContext,
      entityAccess: fbFsDocFormQuestionAccess(
        gFsDatabaseService.firestoreDatabaseContext,
      ),
    );
  });
  muiItem('Question basic entity', () async {
    await goToBasicEntitiesScreen(
      muiBuildContext,
      entityAccess: fbFsFormQuestionAccess(
        gFsDatabaseService.firestoreDatabaseContext,
      ),
    );
  });
  muiItem('Question doc entity', () async {
    await goToDocEntitiesScreen(
      muiBuildContext,
      entityAccess: fbFsDocFormQuestionAccess(
        gFsDatabaseService.firestoreDatabaseContext,
      ),
    );
  });
  muiItem('Firestore explorer', () async {
    await goToFsDocumentRootScreen(
      muiBuildContext,
      firestore: globalFestenaoAdminAppFirebaseContext.firestore,
    );
  });
  muiItem('FsProject list screen', () async {
    await goToFsAppProjectsScreen(muiBuildContext);
  });
  muiItem('FsApp list screen', () async {
    await goToFsAppsScreen(muiBuildContext);
  });
  muiItem('Select FsApp and view users', () async {
    var result = await selectFsApp(muiBuildContext);
    var appId = result?.appId;
    if (muiBuildContext.mounted) {
      await muiSnack(muiBuildContext, 'appId $appId');
    }
    if (appId != null && muiBuildContext.mounted) {
      await goToFsAppUsersScreen(muiBuildContext, appId: appId);
    }
  });
  muiItem('Select Default FsApp', () async {
    var result = await selectFsApp(muiBuildContext);
    var appId = result?.appId;
    globalPrefs.currentAppId = appId;
    if (muiBuildContext.mounted) {
      await muiSnack(muiBuildContext, 'appId $appId, restart app');
    }
  });
  muiItem('App users list screen', () async {
    await goToFsAppUsersScreen(muiBuildContext);
  });

  var appId = globalFestenaoFirestoreDatabaseOrNull?.appId;
  if (appId != null) {
    muiItem('View app $appId', () async {
      await goToFsAppViewScreen(muiBuildContext, appId: appId!);
    });

    muiItem('View custom appId users', () async {
      await goToFsAppUsersScreen(muiBuildContext, appId: appId);
    });
    muiItem('View custom appId projects', () async {
      await goToFsAppProjectsScreen(muiBuildContext, appId: appId);
    });
    muiItem('Prompt custom appId', () async {
      var newAppId = await muiGetString(
        muiBuildContext,
        title: 'App id',
        value: appId,
      );
      if (newAppId != null) {
        appId = newAppId;
      }
    });
    muiItem('Show custom appId', () async {
      await muiSnack(muiBuildContext, 'appId: $appId');
    });
  }
});

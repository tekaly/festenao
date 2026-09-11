/// Dev menu acting on a festenao firebase project through the admin sdk, at
/// three levels: the auth users of the firebase project, the app
/// (`app/<appId>`) and one of its projects (`app/<appId>/project/<projectId>`).
library;

import 'package:festenao_support/src/fb_app_project.dart';
import 'package:tekartik_app_dev_menu/dev_menu.dart';
import 'package:tekartik_firebase_auth/auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Remembers what the menu items act on between two of them, so a user is
/// selected once and every following item applies to it.
class FestenaoFbAppProjectMenuState {
  /// The selected user, null until one is found.
  UserRecord? user;

  /// The selected project id, null until one is selected.
  String? projectId;

  /// A state, [projectId] being the initially selected project, if any.
  FestenaoFbAppProjectMenuState({this.projectId});

  /// The selected user id, or a [StateError] naming what to do about it.
  String get userId {
    var user = this.user;
    if (user == null) {
      throw StateError('no user selected, use \'find user by email\' first');
    }
    return user.uid;
  }

  /// The selected project id, or a [StateError] naming what to do about it.
  String get requireProjectId {
    var projectId = this.projectId;
    if (projectId == null) {
      throw StateError('no project selected, use \'select project\' first');
    }
    return projectId;
  }
}

String _userText(UserRecord user) =>
    '${user.email ?? '<no email>'} (${user.uid})';

String _accessText(TkCmsCvUserAccessCommon access) =>
    'read: ${access.read.v}, write: ${access.write.v}, '
    'admin: ${access.admin.v}, role: ${access.role.v}';

String _appAccessText(FsUserAccess access) =>
    'admin: ${access.admin.v}, role: ${access.role.v}, name: ${access.name.v}';

/// Registers the dev-menu items acting on [appProject].
///
/// Everything goes through the admin sdk, so it reads and creates auth users
/// and bypasses the firestore rules: this belongs in a dev tool, never in an
/// app.
///
/// [projectId] is the initially selected project. [onAppIdSelected] and
/// [onProjectIdSelected] are called when one is picked in the menu, which is
/// how a tool remembers them between runs.
void menuFestenaoFbAppProjectContent({
  required FestenaoFbAppProject appProject,
  String? projectId,
  void Function(String appId)? onAppIdSelected,
  void Function(String projectId)? onProjectIdSelected,
}) {
  var state = FestenaoFbAppProjectMenuState(projectId: projectId);

  void selectApp(String appId) {
    appProject.appId = appId;
    onAppIdSelected?.call(appId);
    write('selected app $appId');
  }

  void selectProject(String projectId) {
    state.projectId = projectId;
    onProjectIdSelected?.call(projectId);
    write('selected project $projectId');
  }

  enter(() async {
    write('Firebase project: ${appProject.firebaseProjectId ?? '<ambient>'}');
    write('App: ${appProject.appId ?? '<none selected>'}');
    write('Project: ${state.projectId ?? '<none selected>'}');
    var user = state.user;
    write('User: ${user == null ? '<none selected>' : _userText(user)}');
  });

  menu('global (users)', () {
    enter(() async {
      write(
        'The auth users of ${appProject.firebaseProjectId ?? 'the project'}.',
      );
      var user = state.user;
      write('User: ${user == null ? '<none selected>' : _userText(user)}');
    });

    item('list users', () async {
      var users = await appProject.listUsers(maxResults: 100);
      if (users.isEmpty) {
        write('no user');
        return;
      }
      for (var user in users) {
        write(_userText(user));
      }
      write('${users.length} user(s)');
    });

    item('find user by email', () async {
      var email = await prompt('email');
      if (email.trim().isEmpty) {
        write('cancelled');
        return;
      }
      var user = await appProject.findUserByEmail(email);
      if (user == null) {
        write('no user found for $email');
        return;
      }
      state.user = user;
      write('selected ${_userText(user)}');
    });

    item('find user by uid', () async {
      var uid = await prompt('uid');
      if (uid.trim().isEmpty) {
        write('cancelled');
        return;
      }
      var user = await appProject.findUser(uid);
      if (user == null) {
        write('no user found for $uid');
        return;
      }
      state.user = user;
      write('selected ${_userText(user)}');
    });

    item('create user (email/password)', () async {
      var email = await prompt('email');
      if (email.trim().isEmpty) {
        write('cancelled');
        return;
      }
      var password = await prompt('password');
      if (password.isEmpty) {
        write('cancelled');
        return;
      }
      var user = await appProject.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      state.user = user;
      write('created and selected ${_userText(user)}');
    });
  });

  menu('app', () {
    enter(() async {
      write('app/${appProject.appId ?? '<appId>'}/user_access/<userId>');
      write('An admin here administers the whole app, not one project.');
    });

    item('list apps', () async {
      // Every id of the `app` collection, the documents that were never
      // written included — those hold the projects all the same.
      var documents = await appProject.appDocuments();
      if (documents.isEmpty) {
        write('no app');
        return;
      }
      for (var document in documents) {
        write('- $document');
      }
      write('${documents.length} app(s)');
    });

    item('pick app', () async {
      var documents = await appProject.appDocuments();
      if (documents.isEmpty) {
        write('no app');
        return;
      }
      await showMenu(() {
        for (var document in documents) {
          item('$document', () {
            selectApp(document.appId);
            popMenu();
          });
        }
      });
    });

    item('enter app id', () async {
      var appId = await prompt('app id');
      if (appId.trim().isEmpty) {
        write('cancelled');
        return;
      }
      selectApp(appId.trim());
    });

    item('list app users', () async {
      var list = await appProject.appUserAccessList();
      if (list.isEmpty) {
        write('no app user access');
        return;
      }
      for (var access in list) {
        write('${access.id}: ${_appAccessText(access)}');
      }
    });

    item('show user access', () async {
      var access = await appProject.getAppUserAccess(state.userId);
      write(_appAccessText(access));
    });

    item('set user as app admin', () async {
      var user = state.user!;
      await appProject.grantAppAdmin(user.uid, name: user.email);
      write('${_userText(user)} is now an admin of ${appProject.appId}');
    });

    item('set user as app super admin', () async {
      var user = state.user!;
      await appProject.grantAppSuperAdmin(user.uid, name: user.email);
      write('${_userText(user)} is now a super admin of ${appProject.appId}');
    });

    item('revoke user app access', () async {
      var userId = state.userId;
      await appProject.revokeAppAccess(userId);
      write('revoked the app access of $userId');
    });
  });

  menu('app project', () {
    enter(() async {
      write(
        'app/${appProject.appId ?? '<appId>'}'
        '/project/${state.projectId ?? '<projectId>'}',
      );
      var user = state.user;
      write('User: ${user == null ? '<none selected>' : _userText(user)}');
    });

    item('list projects', () async {
      var projects = await appProject.projects();
      if (projects.isEmpty) {
        write('no project');
        return;
      }
      for (var project in projects) {
        write('${project.id}: ${project.name.v ?? '<no name>'}');
      }
    });

    item('pick project', () async {
      var projects = await appProject.projects();
      if (projects.isEmpty) {
        write('no project');
        return;
      }
      await showMenu(() {
        for (var project in projects) {
          item('${project.id} ${project.name.v ?? '<no name>'}', () {
            selectProject(project.id);
            popMenu();
          });
        }
      });
    });

    item('select project', () async {
      var projectId = await prompt('project id');
      if (projectId.trim().isEmpty) {
        write('cancelled');
        return;
      }
      selectProject(projectId.trim());
    });

    item('list collections', () async {
      var projectId = state.requireProjectId;
      var collectionIds = await appProject.projectCollectionIds(projectId);
      if (collectionIds.isEmpty) {
        write('no collection');
        return;
      }
      for (var collectionId in collectionIds) {
        write('- $collectionId');
      }
      write('${collectionIds.length} collection(s)');
    });

    item('list project users', () async {
      var list = await appProject.projectUserAccessList(state.requireProjectId);
      if (list.isEmpty) {
        write('no user access');
        return;
      }
      for (var access in list) {
        write('${access.id}: ${_accessText(access)}');
      }
    });

    item('show user access', () async {
      var access = await appProject.getProjectUserAccess(
        projectId: state.requireProjectId,
        userId: state.userId,
      );
      write(_accessText(access));
    });

    for (var grant in FestenaoUserAccessGrant.values) {
      item('grant ${grant.name}', () async {
        var userId = state.userId;
        var projectId = state.requireProjectId;
        await appProject.setProjectUserAccess(
          projectId: projectId,
          userId: userId,
          userAccess: grant.toUserAccess(),
        );
        write('granted ${grant.name} on $projectId to $userId');
      });
    }

    item('revoke user access', () async {
      var userId = state.userId;
      var projectId = state.requireProjectId;
      await appProject.revokeProjectUserAccess(
        projectId: projectId,
        userId: userId,
      );
      write('revoked the access of $userId on $projectId');
    });
  });
}

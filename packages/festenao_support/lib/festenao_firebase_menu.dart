/// Dev menu items acting on a firebase project through admin credentials
/// (service account or admin sdk): auth users, app users, the entities of a
/// tkcms entity database.
///
/// Two flavours:
///
/// - [firebaseFestenaoMenu] (and the generic [firebaseEntityMenu]) list what
///   an already initialised context reaches:
///
///   ```dart
///   mainMenuConsole(args, () {
///     firebaseFestenaoMenu(appFlavorContext, firebaseContext);
///   });
///   ```
///
/// - [menuFestenaoFbAppProjectContent] acts on a [FestenaoFbAppProject] at
///   three levels (auth users, app, app project), finds and creates users and
///   grants access — the context is built lazily on first use:
///
///   ```dart
///   var appProject = FestenaoFbAppProject.firebaseFolder(appId: 'my_app');
///   mainMenuConsole(args, () {
///     menuFestenaoFbAppProjectContent(appProject: appProject);
///   });
///   ```
library;

export 'package:tekartik_app_dev_menu/dev_menu.dart';

export 'src/fb_app_project.dart'
    show
        FestenaoFbAppDocument,
        FestenaoFbAppProject,
        FestenaoUserAccessGrant,
        firebaseFolderProjectId;
export 'src/fb_app_project_menu.dart'
    show FestenaoFbAppProjectMenuState, menuFestenaoFbAppProjectContent;
export 'src/firebase_entity_menu.dart'
    show firebaseEntityMenu, firebaseFestenaoMenu, kvFestenaoProject;

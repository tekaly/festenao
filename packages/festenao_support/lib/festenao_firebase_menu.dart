/// Dev menu items acting on a firebase project through admin credentials
/// (service account or admin sdk): auth users, app users, the entities of a
/// tkcms entity database.
///
/// ```dart
/// mainMenuConsole(args, () {
///   firebaseFestenaoMenu(appFlavorContext, firebaseContext);
/// });
/// ```
///
/// Another app plugs its own entity database in with [firebaseEntityMenu].
library;

export 'package:tekartik_app_dev_menu/dev_menu.dart';

export 'src/firebase_entity_menu.dart'
    show firebaseEntityMenu, firebaseFestenaoMenu, kvFestenaoProject;

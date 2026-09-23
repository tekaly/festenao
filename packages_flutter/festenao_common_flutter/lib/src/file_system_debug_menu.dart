import 'package:festenao_common/firebase/firebase_auth.dart';
import 'package:idb_shim/sdb.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';

import 'file_system_create_action.dart';
import 'file_system_root_picker.dart';
import 'firebase_users_explorer_flutter.dart';
import 'firestore_explorer_flutter.dart';
import 'object_editor/object_value_editor.dart';

/// A debug menu item opening the file system explorer.
///
/// It goes through [FileSystemRootPickerScreen]: the directory is picked
/// among the ones `path_provider` names — documents, support, temporary,
/// downloads, external storage — plus the current one and a scratch memory
/// file system, and the explorer opens sandboxed in it. It edits the json,
/// yaml, text and binary files it finds and browses the sembast and sdb
/// databases; its `+` menu makes a populated demo of each kind.
///
/// [createActions] replaces what that menu offers — a sembast database seeded
/// the way the app wants it, an sdb database with the schema it declares, see
/// [FileSystemCreateAction].
///
/// [sembastDatabaseFactory] and [sdbFactory] are the app's own: pass them and
/// the explorer opens and edits the very databases the app opened.
///
/// Declare it inside a `muiBodyWidget` or a `muiMenu`:
///
/// ```dart
/// muiBodyWidget(() {
///   festenaoFileSystemExplorerMenuItem(packageName: 'com.example.my_app');
/// });
/// ```
void festenaoFileSystemExplorerMenuItem({
  String title = 'File system explorer',
  bool isReadOnly = false,
  String? packageName,
  ObjectValueEditorRegistry? valueEditors,
  List<FileSystemCreateAction>? createActions,
  sembast.DatabaseFactory? sembastDatabaseFactory,
  SdbFactory? sdbFactory,
}) {
  muiItem(title, () {
    goToFileSystemRootPickerScreen(
      muiBuildContext,
      isReadOnly: isReadOnly,
      packageName: packageName,
      valueEditors: valueEditors,
      createActions: createActions,
      sembastDatabaseFactory: sembastDatabaseFactory,
      sdbFactory: sdbFactory,
    );
  });
}

/// A debug menu item opening the firestore explorer on [firestore].
///
/// It lists the collections and opens each document in the object editor, with
/// the firestore types — a timestamp, a blob, a geo point, a reference.
/// [collectionPaths] names them for a backend that cannot list them, the rest
/// api or a client sdk.
///
/// ```dart
/// muiBodyWidget(() {
///   festenaoFirestoreExplorerMenuItem(firestore: myFirestore);
/// });
/// ```
void festenaoFirestoreExplorerMenuItem({
  required Firestore firestore,
  String title = 'Firestore explorer',
  bool isReadOnly = false,
  List<String>? collectionPaths,
  ObjectValueEditorRegistry? valueEditors,
}) {
  muiItem(title, () {
    goToFirestoreExplorerScreen(
      muiBuildContext,
      firestore: firestore,
      isReadOnly: isReadOnly,
      collectionPaths: collectionPaths,
      valueEditors: valueEditors,
    );
  });
}

/// A debug menu item opening the users explorer on [auth].
///
/// It lists the users when the backend can, finds one by uid or email, and
/// creates or deletes one with an admin auth — the admin sdk, the local sdb
/// one.
///
/// ```dart
/// muiBodyWidget(() {
///   festenaoFirebaseUsersExplorerMenuItem(auth: myAuth);
/// });
/// ```
void festenaoFirebaseUsersExplorerMenuItem({
  required FirebaseAuth auth,
  String title = 'Users explorer',
  bool isReadOnly = false,
}) {
  muiItem(title, () {
    goToFirebaseUsersExplorerScreen(
      muiBuildContext,
      auth: auth,
      isReadOnly: isReadOnly,
    );
  });
}

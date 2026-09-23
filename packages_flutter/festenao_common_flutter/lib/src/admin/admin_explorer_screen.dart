import 'package:festenao_common/festenao_firebase.dart' show FirebaseContext;
import 'package:festenao_common/firebase/firebase_service_account.dart';
import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:flutter/material.dart';
import 'package:fs_shim/fs.dart';
import 'package:tekartik_app_flutter_fs/fs.dart' as app_fs;

import '../file_system_create_action.dart';
import '../file_system_root_picker.dart';
import '../firebase_users_explorer_flutter.dart';
import '../firestore_explorer_flutter.dart';
import '../object_editor/object_editor_dialogs.dart';
import '../object_editor/object_explorer_screen.dart';
import '../object_editor/object_value_editor.dart';
import 'admin_credentials.dart';
import 'admin_credentials_screen.dart';

/// The file system an admin build browses: the platform one, the disk on
/// linux.
FileSystem adminFileSystem() => app_fs.fs;

/// The path the whole of [fileSystem] is rooted at: `/` on posix, the drive on
/// windows, `/` for the browser one.
String adminFileSystemRootPath(FileSystem fileSystem) =>
    fileSystem.path.rootPrefix(fileSystem.currentDirectory.path);

/// The roots an admin explorer offers: the whole file system and the home
/// directory on top of the ones an app has, since reaching everything is what
/// an admin build is for.
///
/// [homePath] comes from the caller rather than from `dart:io`, so this stays
/// a library a web build can import; a linux entry point passes
/// `Platform.environment['HOME']`.
List<FileSystemRoot> adminFileSystemRoots({
  FileSystem? fileSystem,
  String? packageName,
  String? homePath,
  bool includeWholeFileSystem = true,
}) {
  var fs = fileSystem ?? adminFileSystem();
  var rootPath = adminFileSystemRootPath(fs);
  return [
    if (includeWholeFileSystem)
      FileSystemRoot(
        name: 'Whole file system',
        description: rootPath,
        resolve: () async => fs.directory(rootPath),
      ),
    if (homePath != null && homePath.isNotEmpty)
      FileSystemRoot(
        name: 'Home',
        description: homePath,
        resolve: () async => fs.directory(homePath),
      ),
    ...festenaoFileSystemRoots(
      fileSystem: fileSystem,
      packageName: packageName,
    ),
  ];
}

/// The admin home: everything an admin build reaches, in one list.
///
/// Firestore and the users of the project through the credentials the app
/// holds, the file system from wherever it is rooted, and any sembast or sdb
/// database file by its path.
///
/// It is the whole of what an admin build is for, so an app shows it behind
/// one item of its start page.
class AdminExplorerScreen extends StatefulWidget {
  /// Where the credentials live.
  final AdminCredentialsDb credentialsDb;

  /// The roots the file system explorer offers, [adminFileSystemRoots] by
  /// default.
  final List<FileSystemRoot>? roots;

  /// The file system the database paths are resolved in, the platform one by
  /// default.
  final FileSystem? fileSystem;

  /// What the `+` menu of the file system explorer offers.
  final List<FileSystemCreateAction>? createActions;

  /// The widget each type is edited with.
  final ObjectValueEditorRegistry? valueEditors;

  /// Names the directory of the app on linux and windows.
  final String? packageName;

  /// Where a backup of the firestore explorer is written, the directory
  /// below [backupDirectoryPath] of the whole file system by default — so an
  /// admin build can back up without being told where first.
  final FileSystemExplorer? backupExplorer;

  /// The directory of [backupExplorer] a backup is written in.
  final String backupDirectoryPath;

  /// The home directory, offered as a root of its own.
  ///
  /// It comes from the caller rather than from `dart:io`, so this stays a
  /// library a web build can import; a linux entry point passes
  /// `Platform.environment['HOME']`.
  final String? homePath;

  /// The title of the screen.
  final String title;

  /// Admin screen on [credentialsDb].
  const AdminExplorerScreen({
    super.key,
    required this.credentialsDb,
    this.roots,
    this.fileSystem,
    this.createActions,
    this.valueEditors,
    this.packageName,
    this.homePath,
    this.backupExplorer,
    this.backupDirectoryPath = '',
    this.title = 'Admin',
  });

  @override
  State<AdminExplorerScreen> createState() => _AdminExplorerScreenState();
}

class _AdminExplorerScreenState extends State<AdminExplorerScreen> {
  AdminCredentialsDb get credentialsDb => widget.credentialsDb;

  late Future<AdminCredentials?> _loading = credentialsDb.current();

  void _reload() => setState(() {
    _loading = credentialsDb.current();
  });

  /// The firebase of the service account last opened, and that account.
  ///
  /// Firebase has one default app per process, so the explorers share it
  /// while the account stays the same; it is deleted when another one is
  /// opened, and when the screen goes.
  (String, Future<FirebaseContext>)? _firebase;

  Future<FirebaseContext> _firebaseContext(
    String serviceAccount,
    Map serviceAccountMap,
  ) async {
    var current = _firebase;
    if (current != null) {
      if (current.$1 == serviceAccount) {
        return current.$2;
      }
      _firebase = null;
      await _deleteFirebase(current.$2);
    }
    var context = festenaoInitFirebaseWithServiceAccount(
      serviceAccountMap: serviceAccountMap,
    );
    _firebase = (serviceAccount, context);
    try {
      return await context;
    } catch (_) {
      if (_firebase?.$2 == context) {
        _firebase = null;
      }
      rethrow;
    }
  }

  static Future<void> _deleteFirebase(Future<FirebaseContext> context) async {
    try {
      await (await context).firebaseApp.delete();
    } catch (_) {
      // It never initialized, or is gone already.
    }
  }

  @override
  void dispose() {
    var current = _firebase;
    if (current != null) {
      _deleteFirebase(current.$2);
    }
    super.dispose();
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// The explorer of the whole file system, so a database anywhere is
  /// reachable by its path.
  FileSystemExplorer _rootExplorer() {
    var fileSystem = widget.fileSystem ?? adminFileSystem();
    return FileSystemExplorer(
      fileSystem: fileSystem,
      rootPath: adminFileSystemRootPath(fileSystem),
    );
  }

  /// [path] as the explorer of everything takes it: relative to the root,
  /// whether it was typed absolute or not.
  String _explorerPath(FileSystemExplorer explorer, String path) {
    var fileSystem = explorer.fileSystem;
    if (!fileSystem.path.isAbsolute(path)) {
      return path;
    }
    return fileSystem.path
        .relative(path, from: explorer.rootPath)
        .replaceAll(r'\\', '/');
  }

  /// The service account of [credentials], null (and said so) when there is
  /// none to use.
  Map? _serviceAccountMap(AdminCredentials? credentials) {
    if (credentials == null) {
      _snack('Pick a set of credentials first');
      return null;
    }
    var serviceAccountMap = credentials.serviceAccountMap;
    if (serviceAccountMap == null) {
      _snack('The service account of ${credentials.displayName} is not json');
    }
    return serviceAccountMap;
  }

  /// The users of the project, through the auth of the service account,
  /// which lists them.
  Future<void> _openUsers(AdminCredentials? credentials) async {
    var serviceAccountMap = _serviceAccountMap(credentials);
    if (credentials == null || serviceAccountMap == null) {
      return;
    }
    try {
      var context = await _firebaseContext(
        credentials.serviceAccount.v!,
        serviceAccountMap,
      );
      if (!mounted) {
        return;
      }
      await goToFirebaseUsersExplorerScreen(
        this.context,
        auth: context.auth,
        title: credentials.projectId.v ?? credentials.displayName,
      );
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _openFirestore(AdminCredentials? credentials) async {
    var serviceAccountMap = _serviceAccountMap(credentials);
    if (credentials == null || serviceAccountMap == null) {
      return;
    }
    try {
      var context = await _firebaseContext(
        credentials.serviceAccount.v!,
        serviceAccountMap,
      );
      if (!mounted) {
        return;
      }
      await goToFirestoreExplorerScreen(
        this.context,
        firestore: context.firestore,
        valueEditors: widget.valueEditors,
        title: credentials.projectId.v ?? credentials.displayName,
        backupExplorer: widget.backupExplorer ?? _rootExplorer(),
        backupDirectoryPath: widget.backupDirectoryPath,
      );
    } catch (e) {
      _snack('$e');
    }
  }

  Future<void> _openFileSystem() async {
    await goToFileSystemRootPickerScreen(
      context,
      roots:
          widget.roots ??
          adminFileSystemRoots(
            fileSystem: widget.fileSystem,
            packageName: widget.packageName,
            homePath: widget.homePath,
          ),
      valueEditors: widget.valueEditors,
      packageName: widget.packageName,
      createActions: widget.createActions,
    );
  }

  /// Opens a database by its path, whatever kind it holds.
  Future<void> _openDatabase({FileSystemDatabaseKind? kind}) async {
    var path = await objectEditorPromptText(
      context,
      title: kind == null ? 'Open a database' : 'Open a ${kind.name} database',
      labelText: 'Path (/home/me/data/my.db)',
    );
    if (path == null || path.isEmpty || !mounted) {
      return;
    }
    var explorer = _rootExplorer();
    FileSystemDatabase database;
    try {
      database = await explorer.openDatabase(
        _explorerPath(explorer, path),
        kind: kind,
      );
    } catch (e) {
      _snack('$e');
      return;
    }
    try {
      if (!mounted) {
        return;
      }
      await goToObjectExplorerScreen(
        context,
        repository: database.repository,
        valueEditors: widget.valueEditors,
      );
    } finally {
      await database.close();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reload',
          onPressed: _reload,
        ),
      ],
    ),
    body: FutureBuilder<AdminCredentials?>(
      future: _loading,
      builder: (context, snapshot) {
        var credentials = snapshot.data;
        return ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.vpn_key_outlined),
              title: const Text('Credentials'),
              subtitle: Text(
                credentials == null
                    ? 'None selected'
                    : '${credentials.displayName} '
                          '(${credentials.projectId.v ?? 'no project'})',
              ),
              onTap: () async {
                await goToAdminCredentialsScreen(
                  context,
                  credentialsDb: credentialsDb,
                );
                _reload();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Firestore explorer'),
              subtitle: Text(
                credentials == null
                    ? 'Pick a set of credentials first'
                    : 'As ${credentials.displayName}, backup included',
              ),
              enabled: credentials != null,
              onTap: () => _openFirestore(credentials),
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Users explorer'),
              subtitle: Text(
                credentials == null
                    ? 'Pick a set of credentials first'
                    : 'As ${credentials.displayName}, listed',
              ),
              enabled: credentials != null,
              onTap: () => _openUsers(credentials),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('File system explorer'),
              subtitle: const Text('Documents, databases, anything'),
              onTap: _openFileSystem,
            ),
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('Sembast explorer'),
              subtitle: const Text('A sembast database, by its path'),
              onTap: () => _openDatabase(kind: FileSystemDatabaseKind.sembast),
            ),
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text('Sdb explorer'),
              subtitle: const Text('An sdb database, by its path'),
              onTap: () => _openDatabase(kind: FileSystemDatabaseKind.sdb),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Any database'),
              subtitle: const Text('Sembast or sdb, told apart by its content'),
              onTap: _openDatabase,
            ),
          ],
        );
      },
    ),
  );
}

/// Pushes an [AdminExplorerScreen].
Future<void> goToAdminExplorerScreen(
  BuildContext context, {
  required AdminCredentialsDb credentialsDb,
  List<FileSystemRoot>? roots,
  FileSystem? fileSystem,
  List<FileSystemCreateAction>? createActions,
  ObjectValueEditorRegistry? valueEditors,
  String? packageName,
  String? homePath,
  FileSystemExplorer? backupExplorer,
  String backupDirectoryPath = '',
  String title = 'Admin',
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => AdminExplorerScreen(
      credentialsDb: credentialsDb,
      roots: roots,
      fileSystem: fileSystem,
      createActions: createActions,
      valueEditors: valueEditors,
      packageName: packageName,
      homePath: homePath,
      backupExplorer: backupExplorer,
      backupDirectoryPath: backupDirectoryPath,
      title: title,
    ),
  ),
);

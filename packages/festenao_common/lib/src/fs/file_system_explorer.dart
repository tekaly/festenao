import 'dart:typed_data';

import 'package:fs_shim/fs.dart';
import 'package:idb_shim/sdb.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast.dart' as sembast;

import '../data/model/object_source.dart';
import '../data/model/object_source_fs.dart';
import '../data/model/object_source_sdb.dart';
import '../data/model/object_source_sembast.dart';
import '../data/model/object_text_format.dart';
import '../data/model/object_type_registry.dart';
import 'sembast_fs_shim.dart';

/// What an entry of a [FileSystemExplorer] holds, guessed from its extension.
enum FileSystemEntryKind {
  /// A directory, the only entry with children.
  directory,

  /// A json document, edited with the object editor.
  json,

  /// A yaml document, edited with the object editor.
  yaml,

  /// A sembast or sdb database file, browsed with the object explorer.
  database,

  /// Anything else that reads as text.
  text,

  /// Anything else.
  binary,
}

/// Which database a `.db` file holds, [FileSystemExplorer.databaseKind] telling
/// them apart by what the file itself contains.
enum FileSystemDatabaseKind {
  /// A plain sembast database, its stores being the ones the app declared.
  sembast,

  /// An sdb (`idb_shim`) database: a sembast file whose main store holds the
  /// indexeddb schema.
  sdb,
}

/// The extensions read as [FileSystemEntryKind.text].
const fileSystemTextExtensions = <String>{
  '.txt',
  '.md',
  '.csv',
  '.log',
  '.dart',
  '.html',
  '.htm',
  '.css',
  '.js',
  '.xml',
  '.svg',
  '.sh',
  '.env',
  '.properties',
  '.lock',
  '.gitignore',
};

/// The extensions read as [FileSystemEntryKind.database].
const fileSystemDatabaseExtensions = <String>{'.db', '.sembast', '.sdb'};

/// The kind of the file at [path], from its extension.
FileSystemEntryKind fileSystemEntryKindOf(String path) {
  var extension = p.posix.extension(path).toLowerCase();
  if (extension == '.json') {
    return FileSystemEntryKind.json;
  }
  if (extension == '.yaml' || extension == '.yml') {
    return FileSystemEntryKind.yaml;
  }
  if (fileSystemDatabaseExtensions.contains(extension)) {
    return FileSystemEntryKind.database;
  }
  if (fileSystemTextExtensions.contains(extension)) {
    return FileSystemEntryKind.text;
  }
  // A dot file with no extension at all (`.gitignore` is an extension to
  // `p.extension`, `LICENSE` is not) reads as text more often than not.
  if (extension.isEmpty) {
    return FileSystemEntryKind.text;
  }
  return FileSystemEntryKind.binary;
}

/// One file or directory of a [FileSystemExplorer].
class FileSystemEntry {
  /// The path relative to the root of the explorer, posix, `''` for the root
  /// itself.
  final String path;

  /// The last segment of [path], what a listing displays.
  final String name;

  /// What the entry holds.
  final FileSystemEntryKind kind;

  /// The size in bytes, null for a directory or when the file system does not
  /// say.
  final int? size;

  /// When the entry was last written, null when the file system does not say.
  final DateTime? modified;

  /// Entry [path] of kind [kind].
  FileSystemEntry({
    required this.path,
    required this.kind,
    this.size,
    this.modified,
  }) : name = path.isEmpty ? '/' : p.posix.basename(path);

  /// True for a directory, the only entry with children.
  bool get isDirectory => kind == FileSystemEntryKind.directory;

  /// True for a json or yaml document, the ones the object editor edits.
  bool get isObject =>
      kind == FileSystemEntryKind.json || kind == FileSystemEntryKind.yaml;

  /// True for a file that may hold a sembast or an sdb database.
  bool get isDatabase => kind == FileSystemEntryKind.database;

  @override
  String toString() => '$path (${kind.name})';
}

/// A path that would leave the root of the explorer.
class FileSystemExplorerPathException implements Exception {
  /// The offending path.
  final String path;

  /// Exception on [path].
  FileSystemExplorerPathException(this.path);

  @override
  String toString() => 'Path outside of the explorer: $path';
}

/// An open database of a [FileSystemExplorer], and what browses it.
///
/// The caller owns it: call [close] when done with it — what a screen does
/// when it is popped.
class FileSystemDatabase {
  /// Which database the file held.
  final FileSystemDatabaseKind kind;

  /// The path of the file, relative to the root of the explorer.
  final String path;

  /// The stores, browsed and edited with the object explorer.
  final ObjectRepository repository;

  /// Closes the database.
  final Future<void> Function() close;

  /// Database [path], browsed through [repository].
  FileSystemDatabase({
    required this.kind,
    required this.path,
    required this.repository,
    required this.close,
  });

  @override
  String toString() => '$path (${kind.name})';
}

/// A file system rooted at one directory, browsed and edited through
/// `fs_shim`.
///
/// It lists what is there, opens a json or yaml document as an [ObjectSource]
/// the object editor edits, and opens a sembast or sdb database file as an
/// [ObjectRepository] the object explorer browses — on io, in memory, or in a
/// browser, since `fs_shim` and the sembast bridge cover all three.
///
/// A read only explorer refuses every write, opens its documents as read only
/// sources and its databases in `DatabaseMode.readOnly`, so handing one out is
/// enough to make a view read only. [readOnly] makes that view of an existing
/// explorer.
///
/// ```dart
/// var explorer = FileSystemExplorer(
///   fileSystem: fileSystemIo,
///   rootPath: '.local',
/// );
/// for (var entry in await explorer.list()) {
///   print(entry);
/// }
/// ```
class FileSystemExplorer {
  /// The file system everything goes through.
  final FileSystem fileSystem;

  /// The directory the explorer is rooted at, a path of [fileSystem].
  final String rootPath;

  /// True when every write is refused.
  final bool isReadOnly;

  /// The types the documents and the records are edited with, the default one
  /// for a document and the backend one for a database record.
  final ObjectTypeRegistry typeRegistry;

  /// The factory the sembast databases are opened with, the `fs_shim` bridge
  /// over [fileSystem] by default.
  ///
  /// Give the one the app itself uses — `databaseFactoryIo`, the sqflite one,
  /// the web one — to open and edit the databases it opened: they are then
  /// the same handles on the same storage, rather than a second one. It must
  /// address the storage this explorer browses, and it is given the path
  /// [nativePath] answers, the one below the sandboxes.
  final sembast.DatabaseFactory? sembastDatabaseFactory;

  /// The factory the sdb databases are opened with, the `fs_shim` bridge over
  /// [fileSystem] by default.
  ///
  /// Give the one the app itself uses — `sdbFactorySqflite`, `sdbFactoryWeb` —
  /// to open and edit the databases it opened. Same contract as
  /// [sembastDatabaseFactory].
  final SdbFactory? sdbFactory;

  /// Explorer of [rootPath] in [fileSystem].
  FileSystemExplorer({
    required this.fileSystem,
    required this.rootPath,
    this.isReadOnly = false,
    ObjectTypeRegistry? typeRegistry,
    this.sembastDatabaseFactory,
    this.sdbFactory,
  }) : typeRegistry = typeRegistry ?? defaultObjectTypeRegistry;

  /// What a screen displays as the title.
  String get title => rootPath;

  /// The same tree, every write refused.
  FileSystemExplorer get readOnly => isReadOnly
      ? this
      : FileSystemExplorer(
          fileSystem: fileSystem,
          rootPath: rootPath,
          isReadOnly: true,
          typeRegistry: typeRegistry,
          sembastDatabaseFactory: sembastDatabaseFactory,
          sdbFactory: sdbFactory,
        );

  /// An explorer rooted at [path] of this one, read only when this one is.
  FileSystemExplorer sub(String path) => FileSystemExplorer(
    fileSystem: fileSystem,
    rootPath: fsPath(path),
    isReadOnly: isReadOnly,
    typeRegistry: typeRegistry,
    sembastDatabaseFactory: sembastDatabaseFactory,
    sdbFactory: sdbFactory,
  );

  /// The path of [fileSystem] the explorer path [path] points at.
  ///
  /// Throws a [FileSystemExplorerPathException] on a path that would leave
  /// [rootPath]: a read only explorer of a directory is contained in it.
  String fsPath(String path) {
    var normalized = p.posix.normalize(path.isEmpty ? '.' : path);
    if (normalized == '.') {
      return rootPath;
    }
    if (p.posix.isAbsolute(normalized) ||
        normalized == '..' ||
        normalized.startsWith('../')) {
      throw FileSystemExplorerPathException(path);
    }
    return fileSystem.path.joinAll([rootPath, ...p.posix.split(normalized)]);
  }

  /// The path [path] has in the storage below the explorer, the sandboxes
  /// unwrapped.
  ///
  /// [fsPath] is what [fileSystem] itself takes; this is what something
  /// underneath it takes — the database factory of the app, addressing the
  /// same file without going through the sandbox. The two are the same when
  /// the explorer is not sandboxed.
  String nativePath(String path) {
    var current = fsPath(path);
    var fs = fileSystem;
    while (fs is FsShimSandboxedFileSystem) {
      current = fs.delegatePath(current);
      fs = fs.rootDirectory.fs;
    }
    return current;
  }

  /// The entries of the directory [path], directories first then files, each
  /// group by name.
  Future<List<FileSystemEntry>> list([String path = '']) async {
    var directory = fileSystem.directory(fsPath(path));
    if (!await directory.exists()) {
      return [];
    }
    var entries = <FileSystemEntry>[];
    await for (var entity in directory.list()) {
      var name = fileSystem.path.basename(entity.path);
      var entryPath = path.isEmpty ? name : p.posix.join(path, name);
      if (entity is Directory) {
        entries.add(
          FileSystemEntry(path: entryPath, kind: FileSystemEntryKind.directory),
        );
      } else if (entity is File) {
        var stat = await entity.stat();
        entries.add(
          FileSystemEntry(
            path: entryPath,
            kind: fileSystemEntryKindOf(entryPath),
            size: stat.size,
            modified: stat.modified,
          ),
        );
      }
    }
    entries.sort((entry1, entry2) {
      if (entry1.isDirectory != entry2.isDirectory) {
        return entry1.isDirectory ? -1 : 1;
      }
      return entry1.name.toLowerCase().compareTo(entry2.name.toLowerCase());
    });
    return entries;
  }

  /// The entry at [path], null when there is nothing there.
  Future<FileSystemEntry?> entry(String path) async {
    var fsPath = this.fsPath(path);
    var type = await fileSystem.type(fsPath);
    if (type == FileSystemEntityType.directory) {
      return FileSystemEntry(path: path, kind: FileSystemEntryKind.directory);
    }
    if (type == FileSystemEntityType.file) {
      var stat = await fileSystem.file(fsPath).stat();
      return FileSystemEntry(
        path: path,
        kind: fileSystemEntryKindOf(path),
        size: stat.size,
        modified: stat.modified,
      );
    }
    return null;
  }

  /// The content of the file at [path] as text.
  Future<String> readAsString(String path) =>
      fileSystem.file(fsPath(path)).readAsString();

  /// The content of the file at [path] as bytes.
  Future<Uint8List> readAsBytes(String path) async =>
      Uint8List.fromList(await fileSystem.file(fsPath(path)).readAsBytes());

  /// The json or yaml document at [path], as the object editor edits it.
  ///
  /// The format comes from the extension, json when it names none. The source
  /// is read only when the explorer is.
  ObjectSource objectSource(String path, {ObjectTextFormat? format}) =>
      FsObjectSource(
        fileSystem.file(fsPath(path)),
        format: format,
        typeRegistry: typeRegistry,
        isReadOnly: isReadOnly,
      );

  /// Which database the file at [path] holds, null when it holds neither.
  ///
  /// It opens the file to tell: an sdb database is a sembast one whose main
  /// store holds the indexeddb schema.
  Future<FileSystemDatabaseKind?> databaseKind(String path) async {
    sembast.Database database;
    try {
      database = await _openSembast(path);
    } catch (_) {
      return null;
    }
    try {
      return await _databaseKindOf(database);
    } catch (_) {
      return null;
    } finally {
      await database.close();
    }
  }

  /// Opens the database at [path] and the [ObjectRepository] browsing it.
  ///
  /// The caller closes it, see [FileSystemDatabase.close]. [kind] skips the
  /// detection when it is already known.
  Future<FileSystemDatabase> openDatabase(
    String path, {
    FileSystemDatabaseKind? kind,
  }) async {
    var database = await _openSembast(path);
    var databaseKind = kind ?? await _databaseKindOf(database);
    if (databaseKind == FileSystemDatabaseKind.sembast) {
      return FileSystemDatabase(
        kind: databaseKind,
        path: path,
        repository: SembastObjectRepository(
          database,
          title: path,
          isReadOnly: isReadOnly,
        ),
        close: database.close,
      );
    }
    // sdb reads the same file through its own factory, so the sembast handle
    // used to detect it goes first.
    await database.close();
    var (sdbDatabaseFactory, sdbPath) = _sdb(path);
    var sdbDatabase = await sdbDatabaseFactory.openDatabase(sdbPath);
    return FileSystemDatabase(
      kind: databaseKind,
      path: path,
      repository: SdbObjectRepository(
        sdbDatabase,
        title: path,
        isReadOnly: isReadOnly,
      ),
      close: sdbDatabase.close,
    );
  }

  /// Creates the directory [path], and the directories above it.
  Future<FileSystemEntry> createDirectory(String path) async {
    _checkWritable('create $path');
    await fileSystem.directory(fsPath(path)).create(recursive: true);
    return FileSystemEntry(path: path, kind: FileSystemEntryKind.directory);
  }

  /// Creates the file [path] with [content], the directories above it
  /// included.
  ///
  /// Throws a [StateError] when something already sits there.
  Future<FileSystemEntry> createFile(String path, {String content = ''}) async {
    _checkWritable('create $path');
    var file = fileSystem.file(fsPath(path));
    if (await file.exists()) {
      throw StateError('$path already exists');
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return (await entry(path))!;
  }

  /// Writes [content] to the file [path], the directories above it included.
  Future<void> writeAsString(String path, String content) async {
    _checkWritable('write $path');
    var file = fileSystem.file(fsPath(path));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// Writes [bytes] to the file [path], the directories above it included.
  Future<void> writeAsBytes(String path, List<int> bytes) async {
    _checkWritable('write $path');
    var file = fileSystem.file(fsPath(path));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    );
  }

  /// Creates a sembast database at [path] and opens it.
  ///
  /// [onCreate] fills it before it is handed back — a demo, a first record, a
  /// schema of your own. The caller closes what comes back, see
  /// [FileSystemDatabase.close].
  ///
  /// Throws a [StateError] when something already sits there: an existing
  /// database is opened with [openDatabase], not created again.
  Future<FileSystemDatabase> createSembastDatabase(
    String path, {
    Future<void> Function(sembast.Database database)? onCreate,
  }) async {
    _checkWritable('create $path');
    await _checkFree(path);
    var (factory, databasePath) = _sembast(path);
    var database = await factory.openDatabase(databasePath);
    try {
      await onCreate?.call(database);
    } catch (_) {
      await database.close();
      rethrow;
    }
    return FileSystemDatabase(
      kind: FileSystemDatabaseKind.sembast,
      path: path,
      repository: SembastObjectRepository(
        database,
        title: path,
        isReadOnly: isReadOnly,
      ),
      close: database.close,
    );
  }

  /// Creates an sdb database at [path], with the stores [schema] declares, and
  /// opens it.
  ///
  /// The schema is where the `cv` sdb helpers come in: declare the records as
  /// `ScvStringRecordBase` models, the stores with `scvStringStoreFactory`,
  /// and hand their `schema()` over.
  ///
  /// ```dart
  /// var noteStore = scvStringStoreFactory.store<DemoNote>('note');
  /// await explorer.createSdbDatabase(
  ///   'notes.db',
  ///   schema: SdbDatabaseSchema(stores: [noteStore.schema()]),
  /// );
  /// ```
  Future<FileSystemDatabase> createSdbDatabase(
    String path, {
    required SdbDatabaseSchema schema,
    int version = 1,
    Future<void> Function(SdbDatabase database)? onCreate,
  }) async {
    _checkWritable('create $path');
    await _checkFree(path);
    var (factory, databasePath) = _sdb(path);
    var database = await factory.openDatabase(
      databasePath,
      options: SdbOpenDatabaseOptions(version: version, schema: schema),
    );
    try {
      await onCreate?.call(database);
    } catch (_) {
      await database.close();
      rethrow;
    }
    return FileSystemDatabase(
      kind: FileSystemDatabaseKind.sdb,
      path: path,
      repository: SdbObjectRepository(
        database,
        title: path,
        isReadOnly: isReadOnly,
      ),
      close: database.close,
    );
  }

  /// Throws a [StateError] when something already sits at [path].
  Future<void> _checkFree(String path) async {
    if (await fileSystem.type(fsPath(path)) != FileSystemEntityType.notFound) {
      throw StateError('$path already exists');
    }
  }

  /// Deletes the file or directory at [path], a directory with what it holds.
  Future<void> delete(String path) async {
    _checkWritable('delete $path');
    if (path.isEmpty) {
      throw FileSystemExplorerPathException(path);
    }
    var fsPath = this.fsPath(path);
    var type = await fileSystem.type(fsPath);
    if (type == FileSystemEntityType.directory) {
      await fileSystem.directory(fsPath).delete(recursive: true);
    } else if (type == FileSystemEntityType.file) {
      await fileSystem.file(fsPath).delete();
    }
  }

  /// Renames the entry at [path] to [newName], in the same directory.
  Future<FileSystemEntry> rename(String path, String newName) async {
    _checkWritable('rename $path');
    if (path.isEmpty || newName.isEmpty || newName.contains('/')) {
      throw FileSystemExplorerPathException(newName);
    }
    var parent = p.posix.dirname(path);
    var newPath = parent == '.' ? newName : p.posix.join(parent, newName);
    var fsPath = this.fsPath(path);
    var newFsPath = this.fsPath(newPath);
    var type = await fileSystem.type(fsPath);
    if (type == FileSystemEntityType.directory) {
      await fileSystem.directory(fsPath).rename(newFsPath);
    } else {
      await fileSystem.file(fsPath).rename(newFsPath);
    }
    return (await entry(newPath))!;
  }

  /// The sembast factory and the path it takes.
  (sembast.DatabaseFactory, String) _sembast(String path) {
    var factory = sembastDatabaseFactory;
    return factory == null
        ? (getDatabaseFactoryFsShim(fileSystem), fsPath(path))
        : (factory, nativePath(path));
  }

  /// The sdb factory and the path it takes.
  (SdbFactory, String) _sdb(String path) {
    var factory = sdbFactory;
    return factory == null
        ? (getSdbFactoryFsShim(fileSystem), fsPath(path))
        : (factory, nativePath(path));
  }

  Future<sembast.Database> _openSembast(String path) {
    var (factory, databasePath) = _sembast(path);
    return factory.openDatabase(
      databasePath,
      mode: isReadOnly
          ? sembast.DatabaseMode.readOnly
          : sembast.DatabaseMode.existing,
    );
  }

  /// An sdb database keeps its indexeddb schema in the sembast main store,
  /// under `stores`; a plain sembast database has nothing there.
  Future<FileSystemDatabaseKind> _databaseKindOf(
    sembast.Database database,
  ) async {
    var stores = await sembast.StoreRef<String, Object>.main()
        .record('stores')
        .get(database);
    return stores is List
        ? FileSystemDatabaseKind.sdb
        : FileSystemDatabaseKind.sembast;
  }

  void _checkWritable(String what) {
    if (isReadOnly) {
      throw ReadOnlyException(what);
    }
  }

  @override
  String toString() =>
      'FileSystemExplorer($rootPath${isReadOnly ? ', read only' : ''})';
}

/// Browsing and editing a file system through `fs_shim`.
///
/// A [FileSystemExplorer] lists a directory tree, opens the json and yaml
/// documents it finds as the object editor edits them (see
/// `data/object_editor.dart`), and opens the sembast and sdb database files it
/// finds as the object explorer browses them.
///
/// It works wherever `fs_shim` does — the disk, memory, indexeddb in a browser
/// — databases included, through the sembast bridge of
/// [getDatabaseFactoryFsShim].
///
/// A read only explorer refuses every write, so handing one out is all it
/// takes to make a view read only.
///
/// The io helpers are in `file_system_explorer_io.dart`, which this library
/// deliberately does not export: everything here imports on the web.
library;

export '../src/fs/file_system_explorer.dart'
    show
        FileSystemDatabase,
        FileSystemDatabaseKind,
        FileSystemEntry,
        FileSystemEntryKind,
        FileSystemExplorer,
        FileSystemExplorerPathException,
        fileSystemDatabaseExtensions,
        fileSystemEntryKindOf,
        fileSystemTextExtensions;
export '../src/fs/sembast_fs_shim.dart'
    show getDatabaseFactoryFsShim, getSdbFactoryFsShim;

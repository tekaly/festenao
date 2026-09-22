/// The flutter side of the file system explorer: browsing a file system and
/// opening what it holds.
///
/// A [FileSystemExplorerScreen] lists a directory of a [FileSystemExplorer]
/// and opens each entry with what fits it: a json or yaml document in the
/// object editor, a sembast or sdb database file in the object explorer, a
/// text file in a text editor.
///
/// It works wherever `fs_shim` does — the disk, memory, indexeddb in a browser
/// — databases included. A read only explorer hides every write action, so
/// `explorer.readOnly` turns the screen into a viewer.
///
/// ```dart
/// await goToFileSystemExplorerScreen(
///   context,
///   explorer: FileSystemExplorer(fileSystem: fileSystemIo, rootPath: '.local'),
/// );
/// ```
library;

export 'package:festenao_common/fs/file_system_explorer.dart';

export 'object_editor_flutter.dart';
export 'src/file_system_create_action.dart'
    show
        FileSystemCreateAction,
        defaultFileSystemCreateActions,
        fileSystemCreateBinaryFileAction,
        fileSystemCreateFileAction,
        fileSystemCreateSdbDatabaseAction,
        fileSystemCreateSembastDatabaseAction,
        fileSystemPromptNewPath;
export 'src/file_system_database_list.dart'
    show
        FileSystemDatabaseEntry,
        FileSystemDatabaseListScreen,
        goToFileSystemDatabaseListScreen,
        listFileSystemDatabases;
export 'src/file_system_debug_menu.dart'
    show festenaoFileSystemExplorerMenuItem;
export 'src/file_system_demo.dart'
    show
        DemoNote,
        DemoTag,
        demoBinaryContent,
        demoJsonContent,
        demoNoteStore,
        demoNoteTitleIndex,
        demoSdbDatabaseSchema,
        demoTagStore,
        demoTextContent,
        demoYamlContent,
        festenaoFileSystemDemoActions,
        fileSystemFreePath,
        fillDemoSdbDatabase,
        fillDemoSembastDatabase,
        initFileSystemDemoBuilders;
export 'src/file_system_hex_editor.dart'
    show
        FileSystemHexFileScreen,
        fileSystemHexBytes,
        fileSystemHexBytesPerRow,
        fileSystemHexOffset,
        fileSystemHexParse,
        fileSystemHexText,
        goToFileSystemHexFileScreen;
export 'src/file_system_root_picker.dart'
    show
        FileSystemRoot,
        FileSystemRootPickerScreen,
        festenaoDirectoryExplorer,
        festenaoFileSystemRoots,
        goToFileSystemRootPickerScreen;
export 'src/files_system_explorer_flutter.dart'
    show
        FileSystemExplorerScreen,
        FileSystemTextFileScreen,
        fileSystemEntryIcon,
        fileSystemFormatSize,
        goToFileSystemExplorerScreen,
        goToFileSystemTextFileScreen;

/// The io side of the file system explorer: an explorer of the local disk.
///
/// Kept apart from `file_system_explorer.dart` so that one imports on the web.
library;

import 'package:fs_shim/fs.dart';
import 'package:fs_shim/fs_io.dart' show fileSystemIo;

import '../src/data/model/object_type_registry.dart';
import '../src/fs/file_system_explorer.dart';

export '../src/data/model/object_type_registry.dart'
    show ObjectTypeRegistry, defaultObjectTypeRegistry;
export 'file_system_explorer.dart';

/// An explorer of the local directory [path].
///
/// [fileSystem] defaults to `fileSystemIo`; a test, or a web simulation,
/// passes a memory one instead.
FileSystemExplorer fileSystemExplorerIo(
  String path, {
  bool isReadOnly = false,
  FileSystem? fileSystem,
  ObjectTypeRegistry? typeRegistry,
}) => FileSystemExplorer(
  fileSystem: fileSystem ?? fileSystemIo,
  rootPath: path,
  isReadOnly: isReadOnly,
  typeRegistry: typeRegistry,
);

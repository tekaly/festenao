import 'package:fs_shim/fs.dart';
import 'package:fs_shim/fs_io.dart' show fileSystemIo;

import '../object_source_fs.dart';
import '../object_text_format.dart';
import '../object_type_registry.dart';

/// A json or yaml file on the local file system.
///
/// The format comes from the extension of [path] unless [format] says
/// otherwise. [fileSystem] defaults to `fileSystemIo`; a test, or a web
/// simulation, passes a memory one instead — which is the whole point of
/// going through `fs_shim`, see [FsObjectSource].
FsObjectSource objectFileSource(
  String path, {
  ObjectTextFormat? format,
  FileSystem? fileSystem,
  ObjectTypeRegistry? typeRegistry,
  bool isReadOnly = false,
}) => FsObjectSource(
  (fileSystem ?? fileSystemIo).file(path),
  format: format,
  typeRegistry: typeRegistry,
  isReadOnly: isReadOnly,
);

/// The json or yaml files of a local directory, each one an editable object.
FsObjectCollection objectDirectoryCollection(
  String path, {
  ObjectTextFormat? format,
  FileSystem? fileSystem,
  ObjectTypeRegistry? typeRegistry,
}) => FsObjectCollection(
  (fileSystem ?? fileSystemIo).directory(path),
  format: format,
  typeRegistry: typeRegistry,
);

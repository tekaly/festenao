import 'package:fs_shim/fs.dart';
import 'package:path/path.dart' as p;

/// The [fileSystem] path of the object storage [posixPath] below [rootPath].
///
/// A leading `/` is relative to the root, `.` and `..` are resolved, a path
/// going above the root throws an [ArgumentError].
String objectStorageFsPath(
  FileSystem fileSystem,
  String rootPath,
  String posixPath,
) {
  var relativePath = posixPath.replaceFirst(RegExp(r'^/+'), '');
  var normalized = p.posix.normalize(relativePath.isEmpty ? '.' : relativePath);
  if (normalized == '..' || normalized.startsWith('../')) {
    throw ArgumentError.value(posixPath, 'path', 'outside of the storage');
  }
  var parts = p.posix
      .split(normalized)
      .where((part) => part.isNotEmpty && part != '.');
  return fileSystem.path.joinAll([rootPath, ...parts]);
}

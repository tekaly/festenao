import 'package:fs_shim/fs_shim.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_system_provider.g.dart';

/// The app [FileSystem].
///
/// Defaults to [fileSystemDefault] (io or web depending on platform).
/// Override to sandbox the file system to an app-specific location or to
/// provide an in-memory file system in tests.
@riverpod
FileSystem festenaoFileSystem(Ref ref) {
  return fileSystemDefault;
}

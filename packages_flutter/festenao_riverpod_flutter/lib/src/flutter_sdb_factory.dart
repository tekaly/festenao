import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fs_shim/fs_shim.dart';
import 'package:idb_sqflite/sdb_sqflite.dart';

/// The raw [SdbFactory] ([sdbFactoryWeb] on the web, [sdbFactorySqflite]
/// otherwise), sandboxed in [fileSystem]'s real (unsandboxed) directory.
///
/// [sdbFactorySqflite] only works out of the box on mobile (iOS/Android); on
/// desktop it needs `sqflite_common`'s `databaseFactory` set to an FFI
/// implementation first. This package depends on `sqflite_ffi`, a
/// self-registering plugin that does exactly that on Linux/macOS/Windows
/// (no-op elsewhere), so no extra setup is required by the app.
///
/// [factory] can be overridden (e.g. with `sdbFactoryMemory`) in tests.
SdbFactory festenaoFlutterSdbFactory(
  FileSystem fileSystem, {
  SdbFactory? factory,
}) {
  factory ??= kIsWeb ? sdbFactoryWeb : sdbFactorySqflite;
  return factory.sandbox(path: fileSystem.unsandbox().path);
}

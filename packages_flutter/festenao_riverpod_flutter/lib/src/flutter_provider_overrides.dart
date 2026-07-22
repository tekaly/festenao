import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:idb_shim/sdb.dart';
import 'package:riverpod/misc.dart';

import 'flutter_file_system.dart';
import 'flutter_sdb_factory.dart';

/// Builds the Flutter riverpod [Override]s for [FestenaoAppFlavorContext],
/// [FileSystem] and [SdbFactory].
///
/// Resolves the application-support-directory [FileSystem] and a real-disk
/// sandboxed [SdbFactory] for [appFlavorContext]. Call this once during app
/// startup (before `runApp`) and pass the result to
/// `ProviderScope(overrides: ...)`.
///
/// [applicationFileSystem] and [rawSdbFactory] can be overridden in tests
/// (e.g. with `fsMemory` and `sdbFactoryMemory`).
Future<List<Override>> festenaoFlutterProviderOverrides({
  required FestenaoAppFlavorContext appFlavorContext,
  FileSystem? applicationFileSystem,
  SdbFactory? rawSdbFactory,
}) async {
  var fileSystem = await festenaoFlutterFileSystem(
    appFlavorContext,
    fileSystem: applicationFileSystem,
  );
  var sdbFactory = festenaoFlutterSdbFactory(
    fileSystem,
    factory: rawSdbFactory,
  );
  return [
    festenaoAppFlavorContextProvider.overrideWithValue(appFlavorContext),
    festenaoFileSystemProvider.overrideWithValue(fileSystem),
    festenaoSdbFactoryProvider.overrideWithValue(sdbFactory),
  ];
}

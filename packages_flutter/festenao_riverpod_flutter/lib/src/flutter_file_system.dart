import 'package:festenao_common/festenao_flavor.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:tekartik_app_flutter_fs/fs.dart' as app_fs;

/// The sandboxed application-support [FileSystem] for [appFlavorContext].
///
/// Uses `tekartik_app_flutter_fs`'s application support directory (`fs` by
/// default) as the sandbox root, further sandboxed under
/// [FestenaoAppFlavorContext.appFlavorContext]'s unique app name sub path.
///
/// [fileSystem] can be overridden (e.g. with `fsMemory`) in tests.
Future<FileSystem> festenaoFlutterFileSystem(
  FestenaoAppFlavorContext appFlavorContext, {
  FileSystem? fileSystem,
}) async {
  var appFileSystem = fileSystem ?? app_fs.fs;
  var supportDirectory = await appFileSystem.getApplicationSupportDirectory();
  return supportDirectory.sandbox().sandbox(
    path: appFlavorContext.appFlavorContext.uniqueAppName,
  );
}

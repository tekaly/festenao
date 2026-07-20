import 'package:fs_shim/fs.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tekartik_app_flutter_fs/fs.dart' as appfs;
import 'app_provider.dart';

part 'fs_providers.g.dart';

/// App filesystem provider
@riverpod
Future<FileSystem> fs(Ref ref) async {
  final appFlavorContext = ref.watch(festenaoAppFlavorContextProvider);

  var fileSystem = (await appfs.fs.getApplicationDocumentsDirectory(
    packageName: appFlavorContext.packageName,
  )).sandbox();

  return fileSystem.sandbox(
    path: appFlavorContext.appFlavorContext.uniqueAppName,
  );
}

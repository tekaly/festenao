// The getting started of the README: a container with the overrides of a
// test or a tool (memory file system and sdb factory).
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:idb_shim/sdb.dart';
import 'package:riverpod/riverpod.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

void main() {
  var container = ProviderContainer(
    overrides: [
      festenaoAppFlavorContextProvider.overrideWithValue(
        FestenaoAppFlavorContext(
          packageName: 'com.example.myapp',
          appFlavorContext: AppFlavorContext.testLocal,
        ),
      ),
      festenaoFileSystemProvider.overrideWithValue(newFileSystemMemory()),
      festenaoSdbFactoryProvider.overrideWithValue(newSdbFactoryMemory()),
    ],
  );
  // ignore: avoid_print
  print(container.read(festenaoAppFlavorContextProvider).appId);
  container.dispose();
}

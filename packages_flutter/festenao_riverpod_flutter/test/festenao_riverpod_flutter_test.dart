import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:festenao_riverpod_flutter/festenao_riverpod_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/sdb.dart';
import 'package:tekartik_app_flutter_fs/fs.dart';

void main() {
  var appFlavorContext = FestenaoAppFlavorContext(
    packageName: 'com.example.test',
    appFlavorContext: AppFlavorContext.test,
  );

  group('festenaoFlutterFileSystem', () {
    test('sandboxes the support directory under the unique app name', () async {
      var fileSystem = await festenaoFlutterFileSystem(
        appFlavorContext,
        fileSystem: fsMemory,
      );

      var unsandboxedPath = fileSystem.file('data.txt').unsandbox().path;
      expect(unsandboxedPath, contains('support'));
      expect(
        unsandboxedPath,
        contains(appFlavorContext.appFlavorContext.uniqueAppName),
      );

      await fileSystem.currentDirectory.create(recursive: true);
      var file = fileSystem.file('data.txt');
      await file.writeAsString('hello');
      expect(await file.readAsString(), 'hello');
    });
  });

  group('festenaoFlutterSdbFactory', () {
    test('sandboxes the raw factory in the file system directory', () async {
      var fileSystem = await festenaoFlutterFileSystem(
        appFlavorContext,
        fileSystem: fsMemory,
      );
      var sdbFactory = festenaoFlutterSdbFactory(
        fileSystem,
        factory: sdbFactoryMemory,
      );

      var fullPath = await sdbFactory.getDatabaseFullPath('mydb');
      expect(
        fullPath,
        contains(appFlavorContext.appFlavorContext.uniqueAppName),
      );
    });
  });

  group('festenaoFlutterProviderOverrides', () {
    test('wires the file system, sdb factory and flavor context', () async {
      var overrides = await festenaoFlutterProviderOverrides(
        appFlavorContext: appFlavorContext,
        applicationFileSystem: fsMemory,
        rawSdbFactory: sdbFactoryMemory,
      );
      var container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(
        container.read(festenaoAppFlavorContextProvider),
        same(appFlavorContext),
      );

      var fileSystem = container.read(festenaoFileSystemProvider);
      expect(
        fileSystem.unsandbox().path,
        contains(appFlavorContext.appFlavorContext.uniqueAppName),
      );

      var sdbFactory = container.read(festenaoSdbFactoryProvider);
      var fullPath = await sdbFactory.getDatabaseFullPath('mydb');
      expect(
        fullPath,
        contains(appFlavorContext.appFlavorContext.uniqueAppName),
      );
    });
  });
}

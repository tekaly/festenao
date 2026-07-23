import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:idb_shim/sdb.dart';
import 'package:riverpod/misc.dart';
import 'package:riverpod/riverpod.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:test/test.dart';

void main() {
  group('festenaoFileSystemProvider', () {
    test('overridden with an in-memory file system', () async {
      var fileSystem = newFileSystemMemory();
      var container = ProviderContainer(
        overrides: [festenaoFileSystemProvider.overrideWithValue(fileSystem)],
      );
      addTearDown(container.dispose);

      var fs = container.read(festenaoFileSystemProvider);
      expect(fs, same(fileSystem));

      var file = fs.file('test.txt');
      await file.writeAsString('hello');
      expect(await file.readAsString(), 'hello');
    });
  });

  group('festenaoSdbFactoryProvider', () {
    test('overridden with an in-memory factory', () async {
      var container = ProviderContainer(
        overrides: [
          festenaoSdbFactoryProvider.overrideWithValue(sdbFactoryMemory),
        ],
      );
      addTearDown(container.dispose);

      var factory = container.read(festenaoSdbFactoryProvider);
      expect(factory, same(sdbFactoryMemory));

      var store = SdbStoreRef<String, SdbModel>('items');
      var db = await factory.openDatabase(
        'test.db',
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [store.schema()]),
        ),
      );
      addTearDown(db.close);

      await store.record('a').put(db, {'value': 1});
      var snapshot = await store.record('a').get(db);
      expect(snapshot?.value, {'value': 1});
    });

    test('sandboxes using the app flavor context unique app name', () async {
      var context = FestenaoAppFlavorContext(
        packageName: 'com.example.test',
        appFlavorContext: AppFlavorContext.test,
      );
      var sandboxed = sdbFactoryMemory.sandbox(
        path: context.appFlavorContext.uniqueAppName,
      );

      var fullPath = await sandboxed.getDatabaseFullPath('mydb');
      expect(fullPath, contains(context.appFlavorContext.uniqueAppName));
    });
  });

  group('festenaoAppFlavorContextProvider', () {
    test('throws when not overridden', () {
      var container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(festenaoAppFlavorContextProvider),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.exception,
            'exception',
            isUnimplementedError,
          ),
        ),
      );
    });

    test('overridden with a test flavor context', () {
      var context = FestenaoAppFlavorContext(
        packageName: 'com.example.test',
        appFlavorContext: AppFlavorContext.test,
      );
      var container = ProviderContainer(
        overrides: [
          festenaoAppFlavorContextProvider.overrideWithValue(context),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(festenaoAppFlavorContextProvider), same(context));
    });
  });

  group('festenaoFirebaseAppProvider', () {
    test('overridden with an in-memory Firebase app', () async {
      var firebaseApp = newFirebaseMemory().initializeApp();
      var container = ProviderContainer(
        overrides: [festenaoFirebaseAppProvider.overrideWithValue(firebaseApp)],
      );
      addTearDown(container.dispose);

      expect(container.read(festenaoFirebaseAppProvider), same(firebaseApp));
    });
  });
}

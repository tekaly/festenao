import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:idb_shim/sdb.dart';
import 'package:riverpod/misc.dart';
import 'package:tkcms_common/tkcms_auth.dart';

import 'flutter_file_system.dart';
import 'flutter_sdb_factory.dart';
import 'user_projects_sdb_manager_override.dart';

/// Builds the Flutter riverpod [Override]s for [FestenaoAppFlavorContext],
/// [FileSystem], [SdbFactory] and, when [projectsApp] is provided,
/// [UserProjectsSdbManager].
///
/// Resolves the application-support-directory [FileSystem] and a real-disk
/// sandboxed [SdbFactory] for [appFlavorContext]. Call this once during app
/// startup (before `runApp`) and pass the result to
/// `ProviderScope(overrides: ...)`.
///
/// [applicationFileSystem] and [rawSdbFactory] can be overridden in tests
/// (e.g. with `fsMemory` and `sdbFactoryMemory`).
///
/// [projectsApp] is only needed when the app uses the per user projects
/// database; see [festenaoUserProjectsSdbManagerOverride] for details on
/// [identityBloc] and how its Firestore instance is resolved from
/// [festenaoFirebaseAppProvider].
Future<List<Override>> festenaoFlutterProviderOverrides({
  required FestenaoAppFlavorContext appFlavorContext,
  FileSystem? applicationFileSystem,
  SdbFactory? rawSdbFactory,
  TkCmsFbIdentityBloc? identityBloc,
}) async {
  var fileSystem = await festenaoFlutterFileSystem(
    appFlavorContext,
    fileSystem: applicationFileSystem,
  );
  var sdbFactory = festenaoFlutterSdbFactory(
    fileSystem,
    factory: rawSdbFactory,
  );
  var appId = appFlavorContext.appId;

  return [
    festenaoAppFlavorContextProvider.overrideWithValue(appFlavorContext),
    festenaoFileSystemProvider.overrideWithValue(fileSystem),
    festenaoSdbFactoryProvider.overrideWithValue(sdbFactory),
    festenaoUserProjectsSdbManagerProvider.overrideWith((ref) {
      var firebaseApp = ref.watch(festenaoFirebaseAppProvider);
      var manager = UserProjectsSdbManager(
        factory: sdbFactory,
        firestore: firebaseApp.firestore(),
        app: appId,
      );
      var bloc = identityBloc ?? globalTkCmsFbIdentityBloc;
      bloc.state.listen((state) {
        manager.setCurrentUser(state.identity?.userId);
      });
      return manager;
    }),
    /*
    festenaoUserProjectsSdbManagerOverride(
      factory: sdbFactory,
      app: appId,
      identityBloc: identityBloc,
    ),*/
  ];
}

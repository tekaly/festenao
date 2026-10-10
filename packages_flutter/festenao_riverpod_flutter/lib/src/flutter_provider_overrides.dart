import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:fs_shim/fs_shim.dart';
import 'package:idb_shim/sdb.dart';
import 'package:riverpod/misc.dart';
import 'package:tkcms_common/tkcms_auth.dart';

import 'flutter_file_system.dart';
import 'flutter_sdb_factory.dart';

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
/// (e.g. with `fsMemory` and `sdbFactoryMemory`). They are the raw ones, not
/// sandboxed yet: see [festenaoProviderOverrides] for already resolved ones.
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
  return festenaoProviderOverrides(
    appFlavorContext: appFlavorContext,
    fileSystem: fileSystem,
    sdbFactory: sdbFactory,
  );
}

/// The same [Override]s as [festenaoFlutterProviderOverrides], from a
/// [fileSystem] and an [sdbFactory] already resolved for [appFlavorContext]
/// (by [festenaoFlutterFileSystem] and [festenaoFlutterSdbFactory]).
///
/// For an app that needs them before building its overrides (its own
/// databases, a local firebase): passing them to
/// [festenaoFlutterProviderOverrides] instead would sandbox them a second
/// time, and the databases would end up in a doubled path.
List<Override> festenaoProviderOverrides({
  required FestenaoAppFlavorContext appFlavorContext,
  required FileSystem fileSystem,
  required SdbFactory sdbFactory,
}) {
  var appId = appFlavorContext.appId;
  return [
    festenaoAppFlavorContextProvider.overrideWithValue(appFlavorContext),
    festenaoFileSystemProvider.overrideWithValue(fileSystem),
    festenaoSdbFactoryProvider.overrideWithValue(sdbFactory),
    festenaoUserProjectsSdbManagerOverride(factory: sdbFactory, app: appId),
  ];
}

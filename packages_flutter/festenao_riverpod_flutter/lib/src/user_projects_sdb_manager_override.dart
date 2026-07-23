import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Builds the [festenaoUserProjectsSdbManagerProvider] riverpod [Override]
/// for a per user [UserProjectsSdbManager].
///
/// The [Firestore] instance is resolved from [festenaoFirebaseAppProvider]
/// (`app.firestore()`), so overriding that provider (e.g. in tests) also
/// changes the database this manager syncs to.
///
/// [globalProjectsSdbOrNull] then follows [identityBloc]'s identity: a per
/// user database synced to firestore
/// `app/<app>/user_prv/<userId>/data/projects` (locally sandboxed to the
/// user id) when authenticated, otherwise a plain local database.
///
/// Unlike the dashboard app's `initFestenaoUserProjectsSdbManager`, no global
/// manager variable is set here. Call this once during app startup and pass
/// the result to `ProviderScope(overrides: ...)`.
Override festenaoUserProjectsSdbManagerOverride({
  required SdbFactory factory,
  required String app,
  String? name,
  TkCmsFbIdentityBloc? identityBloc,
}) {
  return festenaoUserProjectsSdbManagerProvider.overrideWith((ref) {
    var firebaseApp = ref.watch(festenaoFirebaseAppProvider);
    var manager = UserProjectsSdbManager(
      factory: factory,
      firestore: firebaseApp.firestore(),
      app: app,
      name: name,
    );
    var appFlavorContext = ref
        .watch(festenaoAppFlavorContextProvider)
        .appFlavorContext;
    var firebaseContext = TkCmsFirebaseContext.fromApp(
      firebaseApp: firebaseApp,
    );
    var fsDatabase = FestenaoFirestoreDatabase(
      firebaseContext: firebaseContext,
      flavorContext: appFlavorContext,
    );
    // Compat needed
    globalFestenaoFirestoreDatabaseOrNull = fsDatabase;
    var bloc = identityBloc ?? globalTkCmsFbIdentityBloc;
    bloc.state.listen((state) {
      manager.setCurrentUser(state.identity?.userId);
    });
    /*var fsProjectDb = globalFestenaoFirestoreDatabase.projectDb;
    // Compat needed
    globalFestenaoUserProjectsSdbBloc = FestenaoUserProjectsSdbBloc(
      appFlavorContext: appFlavorContext,
      firebaseUserStream: firebaseContext.auth.onCurrentUser,
      fsProjectDb: fsProjectDb,
      projectsSdb: globalProjectsSdb,
    );*/
    return manager;
  });
}

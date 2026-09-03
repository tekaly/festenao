import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

import 'app_flavor_context_provider.dart';
import 'firebase_app_provider.dart';
import 'user_projects_sdb_manager_provider.dart';
import 'user_projects_sdb_provider.dart';

/// Builds the [festenaoUserProjectsSdbManagerProvider] riverpod [Override]
/// for a per user [UserProjectsSdbManager].
///
/// The [Firestore] instance is resolved from [festenaoFirebaseAppProvider]
/// (`app.firestore()`), so overriding that provider (e.g. in tests) also
/// changes the database this manager syncs to.
///
/// [festenaoUserProjectsSdbProvider] then follows the identity of
/// [identityBloc] — by default a [TkCmsFbIdentityBloc] bound to the auth of
/// that firebase app, so a local or test firebase never has to touch the
/// global bloc: a per user database synced to firestore
/// `app/<app>/user_prv/<userId>/data/projects` (locally sandboxed to the user
/// id) when authenticated, otherwise a plain local database.
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
    // Our own bloc when none is given: the global one is bound to
    // `FirebaseAuth.instance`, which a local or test firebase is not.
    var ownBloc = identityBloc == null;
    var bloc = identityBloc ?? TkCmsFbIdentityBloc(auth: firebaseContext.auth);
    var subscription = bloc.state.listen((state) {
      manager.setCurrentUser(state.identity?.userId);
    });
    ref.onDispose(() {
      subscription.cancel();
      if (ownBloc) {
        bloc.dispose();
      }
      manager.close();
    });
    return manager;
  });
}

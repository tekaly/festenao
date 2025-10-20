import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_firebase.dart';
import 'package:festenao_common/firebase/firebase_sim.dart';
import 'package:sembast/sembast_io.dart';

export 'package:tekartik_firebase_auth_sim/auth_sim.dart';
export 'package:tekartik_firebase_auth_test/menu/firebase_auth_client_menu.dart';
export 'package:tekartik_firebase_firestore_sim/firestore_sim.dart';
export 'package:tekartik_firebase_firestore_test/menu/firestore_client_menu.dart';
export 'package:tekartik_firebase_functions_call_sim/functions_call_sim.dart';
export 'package:tekartik_firebase_functions_test/menu/firebase_functions_call_client_menu.dart';
export 'package:tekartik_firebase_sim/firebase_sim.dart';
export 'package:tekartik_firebase_storage_sim/storage_sim.dart';

/// Initializes Firebase IO with a service account map.
///
/// Returns a [FirebaseContext] containing the initialized Firebase services.
Future<FirebaseContext> festenaoInitFirebaseSim({
  Uri? uri,

  /// Optional Firebase app options.
  FirebaseAppOptions? options,
}) async {
  var firebase = getFirebaseSim(uri: uri);
  var firebaseAuthService = FirebaseAuthServiceSim(
    databaseFactory: databaseFactoryIo,
  );
  var firestoreService = firestoreServiceSim;
  var storageService = storageServiceSim;
  var firebaseApp = await firebase.initializeAppAsync(options: options);
  return FirebaseServicesContext(
    firebase: firebase,
    firestoreService: firestoreService,
    authService: firebaseAuthService,
    storageService: storageService,
    firebaseApp: firebaseApp,
  ).init();
}

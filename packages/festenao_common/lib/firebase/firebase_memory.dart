import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_firebase.dart';
import 'package:tekartik_firebase_auth_sembast/auth_sembast.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:tekartik_firebase_storage_fs/storage_fs.dart';

export 'package:tekartik_firebase_auth_sembast/auth_sembast.dart';
export 'package:tekartik_firebase_auth_test/menu/firebase_auth_client_menu.dart';
export 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
export 'package:tekartik_firebase_firestore_test/menu/firestore_client_menu.dart';
export 'package:tekartik_firebase_functions_call_sim/functions_call_sim.dart';
export 'package:tekartik_firebase_local/firebase_local.dart';
export 'package:tekartik_firebase_storage_fs/storage_fs.dart';

/// Initializes Firebase IO with a service account map.
///
/// Returns a [FirebaseContext] containing the initialized Firebase services.
Future<FirebaseContext> festenaoInitFirebaseMemory({
  /// Optional Firebase app options.
  FirebaseAppOptions? options,
}) async {
  var firebase = newFirebaseMemory();
  var firebaseAuthService = newFirebaseAuthServiceMemory();
  var firestoreService = newFirestoreServiceMemory();
  var storageService = newStorageServiceMemory();
  var firebaseApp = await firebase.initializeAppAsync(options: options);
  return FirebaseServicesContext(
    firebase: firebase,
    firestoreService: firestoreService,
    authService: firebaseAuthService,
    storageService: storageService,
    firebaseApp: firebaseApp,
  ).init();
}

import 'package:festenao_common/festenao_firebase.dart';

import '../festenao_firebase_rest.dart';

export 'package:tekartik_firebase_auth_rest/auth_rest.dart';
export 'package:tekartik_firebase_firestore_rest/firestore_rest.dart';
export 'package:tekartik_firebase_rest/firebase_rest.dart';
export 'package:tekartik_firebase_storage_rest/storage_rest.dart';

/// Initializes Firebase IO with a service account map.
///
/// Returns a [FirebaseContext] containing the initialized Firebase services.
Future<FirebaseContext> festenaoInitFirebaseRest({
  /// Optional Firebase app options.
  FirebaseAppOptions? options,
}) async {
  var firebase = firebaseRest;

  return FirebaseServicesContext(
    firebase: firebase,
    appOptions: options,
    firestoreService: firestoreServiceRest,
    authService: firebaseAuthServiceRest,
    storageService: storageServiceRest,
  ).init();
}

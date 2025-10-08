import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_firebase.dart';
import 'package:festenao_common/festenao_firebase_rest.dart';

/// Initializes Firebase IO with a service account map.
///
/// Returns a [FirebaseContext] containing the initialized Firebase services.
Future<FirebaseContext> festenaoInitFirebaseIoWithServiceAccount({
  required Map serviceAccountMap,
}) async {
  //initFirebaseIo();

  var firebaseAdmin = firebaseRest;

  var firebaseApp = await firebaseAdmin.initializeAppWithServiceAccountMap(
    serviceAccountMap,
  );
  await firebaseAdmin.credential.applicationDefault()?.getAccessToken();
  return FirebaseServicesContext(
    firebase: firebaseAdmin,
    firestoreService: firestoreServiceRest,
    authService: firebaseAuthServiceRest,
    storageService: storageServiceRest,
    firebaseApp: firebaseApp,
  ).initContext();
}

import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_firebase.dart';
import 'package:festenao_common/festenao_firebase_rest.dart';
import 'package:tekartik_firebase_functions_call_rest/functions_call_rest.dart';

/// Initializes Firebase for IO environments using a [serviceAccountMap].
///
/// [options] optional custom [FirebaseAppOptions].
/// [serviceAccountMap] map containing service account credentials JSON.
/// [storageBucket] optional custom Firebase Storage bucket name.
///
/// Returns a [FirebaseContext] containing initialized Firebase services.
Future<FirebaseContext> festenaoInitFirebaseIoWithServiceAccount({
  FirebaseAppOptions? options,
  required Map serviceAccountMap,
  String? storageBucket,
}) async {
  //initFirebaseIo();

  var firebaseAdmin = firebaseRest;

  var firebaseApp = await firebaseAdmin.initializeAppWithServiceAccountMap(
    serviceAccountMap,
    options: options,
  );
  await firebaseAdmin.credential.applicationDefault()?.getAccessToken();
  return FirebaseServicesContext(
    firebase: firebaseAdmin,
    firestoreService: firestoreServiceRest,
    authService: firebaseAuthServiceRest,
    storageService: storageServiceRest,
    functionsCallService: firebaseFunctionsCallServiceRest,
    functionsCallRegion: regionBelgium,
    firebaseApp: firebaseApp,
  ).init();
}

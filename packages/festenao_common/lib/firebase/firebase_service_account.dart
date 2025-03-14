import 'package:festenao_common/festenao_firebase_rest.dart';
import 'package:meta/meta.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

/// Internal use only
@visibleForTesting
Future<FirebaseContext> festenaoInitFirebaseWithServiceAccount({
  required Map serviceAccountMap,
}) async {
  var firebaseAdmin = firebaseRest;

  var firebaseApp = await firebaseAdmin.initializeAppWithServiceAccountMap(
    serviceAccountMap,
  );
  //await firebaseAdmin.credential.applicationDefault()?.getAccessToken();
  return FirebaseServicesContext(
    firebase: firebaseAdmin,
    firestoreService: firestoreServiceRest,
    storageService: storageServiceRest,
    authService: firebaseAuthServiceRest,
    firebaseApp: firebaseApp,
  ).initContext();
}

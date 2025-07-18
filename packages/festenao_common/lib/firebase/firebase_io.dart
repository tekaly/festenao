import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_firebase.dart';
import 'package:festenao_common/festenao_firebase_rest.dart';

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
    firebaseApp: firebaseApp,
  ).initContext();
}

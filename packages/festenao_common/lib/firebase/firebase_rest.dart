import 'package:festenao_common/festenao_firebase.dart';
import 'package:tekartik_common_utils/env_utils.dart';
import 'package:tekartik_firebase_functions_call_rest/functions_call_rest.dart';

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

/// festenao services
Future<FirebaseServicesContext> festenaoInitFirebaseServicesContextRest({
  required FirebaseAppOptions appOptions,
  GoogleAuthOptions? googleAuthOptions,
}) async {
  var firebase = firebaseRest;
  var firestoreService = firestoreServiceRest;
  var storageService = storageServiceRest;
  var functionsCallService = firebaseFunctionsCallServiceRest;
  var authService = FirebaseAuthServiceRest(
    persistence: FirebaseRestAuthPersistenceFile(),
    providers: () => <AuthProviderRest>[
      // When adding google, must also provider built-in one...but why?
      BuiltInAuthProviderRest(),
      if (!kDartIsWeb && (googleAuthOptions != null))
        GoogleAuthProviderRestIo(
          options: googleAuthOptions,
          credentialPath:
              '.local/google_auth_firebase_${appOptions.projectId}.json',
        ),
    ],
  );
  var firebaseServicesContext = FirebaseServicesContext(
    appOptions: appOptions,
    firebase: firebase,
    authService: authService,
    firestoreService: firestoreService,
    storageService: storageService,
    functionsCallService: functionsCallService,
    functionsCallRegion: regionBelgium,
  );
  return firebaseServicesContext;
}

/// Festenao rest app
Future<FirebaseContext> festenaoInitFirebaseRestApp({
  required FirebaseAppOptions appOptions,
  GoogleAuthOptions? googleAuthOptions,
}) async {
  var firebaseServicesContext = await festenaoInitFirebaseServicesContextRest(
    appOptions: appOptions,
    googleAuthOptions: googleAuthOptions,
  );
  return await firebaseServicesContext.init();
}

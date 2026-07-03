import 'package:festenao_dartff/functions.dart';
import 'package:tekartik_firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:tekartik_firebase_admin_sdk/firebase_auth_admin_sdk.dart';
import 'package:tekartik_firebase_admin_sdk/firebase_storage_admin_sdk.dart';
import 'package:tekartik_firebase_admin_sdk/firestore_admin_sdk.dart';
import 'package:tekartik_firebase_functions_admin_sdk/functions_admin_sdk.dart';
import 'package:tkcms_common/firebase/firebase.dart';
import 'package:tkcms_common/server/server_admin_sdk.dart';
import 'package:tkcms_common/server/server_common.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

const _httpsOptions = HttpsOptions(
  cors: Cors(['*']),
  region: Region(SupportedRegion.europeWest1),
);
const _callableOptions = CallableOptions(
  cors: Cors(['*']),
  region: Region(SupportedRegion.europeWest1),
);

/// Admin sdk based services.
FirebaseServicesContext initFirebaseServicesAdminSdk() {
  var firebase = firebaseAdminSdk;
  var firestoreService = firestoreServiceAdminSdk;

  var authService = firebaseAuthServiceAdminSdk;
  var storageService = firebaseStorageServiceAdminSdk;
  var firebaseServicesContext = FirebaseServicesContext(
    firebase: firebase,
    authService: authService,
    firestoreService: firestoreService,
    storageService: storageService,
  );
  return firebaseServicesContext;
}

void main(List<String> args) {
  runFunctions((firebase) async {
    var fbContext = (initFirebaseServicesAdminSdk().copyWith(
      firebaseApp: firebase.firebaseApp,
    )).initSync();

    var appDev = FfApp(
      context: TkCmsServerAppContext(
        firebaseContext: fbContext,
        flavorContext: FlavorContext.dev,
      ),
    );

    // https://firebase.google.com/docs/functions/http-events
    firebase.https.onRequest(
      name: functionCommandDartV2Dev,
      options: _httpsOptions,
      firebase.httpsHandler(appDev.functionsHttpDartV2Handler),
    );
    firebase.https.onCall(
      name: callableFunctionCommandDartV2Dev,
      options: _callableOptions,
      firebase.callHandler(appDev.functionsCallDartV2Handler),
    );
    firebase.https.onRequest(
      name: 'ampdev',
      options: _httpsOptions,
      firebase.httpsHandler(festenaoAmpDartV2Handler),
    );

    var appProd = FfApp(
      context: TkCmsServerAppContext(
        firebaseContext: fbContext,
        flavorContext: FlavorContext.prod,
      ),
    );

    // https://firebase.google.com/docs/functions/http-events
    firebase.https.onRequest(
      name: functionCommandDartV2Prod,
      options: _httpsOptions,
      firebase.httpsHandler(appProd.functionsHttpDartV2Handler),
    );
    firebase.https.onCall(
      name: callableFunctionCommandDartV2Prod,
      options: _callableOptions,
      firebase.callHandler(appProd.functionsCallDartV2Handler),
    );
    firebase.https.onRequest(
      name: 'amp',
      options: _httpsOptions,
      firebase.httpsHandler(festenaoAmpDartV2Handler),
    );
  });
}

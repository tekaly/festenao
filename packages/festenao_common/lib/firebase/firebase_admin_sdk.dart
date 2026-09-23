/// Firebase through the admin sdk, for io only (a server, a tool): not for
/// the web.
library;

import 'package:festenao_common/festenao_firebase.dart';
import 'package:tekartik_firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:tkcms_common/firebase/admin_sdk.dart';

export 'package:tkcms_common/firebase/admin_sdk.dart'
    show initFirebaseServicesAdminSdk;

/// Initializes Firebase through the admin sdk using a [serviceAccountMap].
///
/// The admin sdk counterpart of `festenaoInitFirebaseRestIoWithServiceAccount`
/// (`firebase_io.dart`): firestore, auth (an admin, which lists, creates and
/// deletes users) and storage go through the admin sdk instead of the rest
/// apis. [options] overrides app options such as the storage bucket.
///
/// Returns a [FirebaseContext] containing initialized Firebase services.
Future<FirebaseContext> festenaoInitFirebaseAdminSdkWithServiceAccount({
  FirebaseAppOptions? options,
  required Map serviceAccountMap,
}) async {
  var firebaseApp = await firebaseAdminSdk.initializeAppWithServiceAccountMap(
    serviceAccountMap,
    options: options,
  );
  return initFirebaseServicesAdminSdk()
      .copyWith(firebaseApp: firebaseApp)
      .initSync();
}

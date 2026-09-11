import 'package:tekartik_firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:tkcms_common/firebase/admin_sdk.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

/// Initializes firebase through the admin sdk, with a service account map (the
/// parsed content of a service account json).
///
/// Returns a [FirebaseContext] with firestore, auth and storage.
Future<FirebaseContext> festenaoInitFirebaseAdminSdkWithServiceAccount({
  required Map serviceAccountMap,

  /// Optional firebase app options (storage bucket, …).
  FirebaseAppOptions? options,
}) async {
  var servicesContext = initFirebaseServicesAdminSdk();
  var firebaseAdmin = servicesContext.firebase as FirebaseAdminSdk;
  var firebaseApp = await firebaseAdmin.initializeAppWithServiceAccountMap(
    serviceAccountMap,
    options: options,
  );
  return servicesContext.copyWith(firebaseApp: firebaseApp).initContext();
}

/// Initializes firebase through the admin sdk for [projectId], using the
/// ambient credentials (`gcloud auth application-default login`, or the
/// service account of the machine it runs on).
///
/// [festenaoInitFirebaseAdminSdkWithServiceAccount] is the one to use when the
/// credentials are checked in a private repository instead.
Future<FirebaseContext> festenaoInitFirebaseAdminSdk({
  required String projectId,
  String? storageBucket,
}) async {
  var servicesContext = initFirebaseServicesAdminSdk();
  var firebaseApp = servicesContext.firebase.initializeApp(
    options: FirebaseAppOptions(
      projectId: projectId,
      storageBucket: storageBucket,
    ),
  );
  return servicesContext.copyWith(firebaseApp: firebaseApp).initContext();
}

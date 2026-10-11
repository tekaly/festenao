/// Firebase through the admin sdk, for io only (a server, a tool): not for
/// the web.
library;

import 'package:festenao_common/admin/festenao_apps_admin.dart';
import 'package:festenao_common/festenao_firebase.dart';
import 'package:tekartik_firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:tekartik_firebase_admin_sdk/firestore_admin_sdk.dart';
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

/// Initializes Firebase of [projectId] through the admin sdk, as the
/// application default credentials of the machine.
///
/// No service account: the admin sdk finds the credentials itself, the json
/// of `GOOGLE_APPLICATION_CREDENTIALS` or else the gcloud user of
/// `gcloud auth application-default login`
/// (`~/.config/gcloud/application_default_credentials.json`), who needs the
/// rights on the project (an owner, an editor).
///
/// As a gcloud user, auth needs a quota project:
/// `GOOGLE_CLOUD_QUOTA_PROJECT=<projectId>` in the environment, or
/// `gcloud auth application-default set-quota-project <projectId>`.
/// [options] overrides app options such as the storage bucket.
Future<FirebaseContext> festenaoInitFirebaseAdminSdkWithApplicationDefault({
  FirebaseAppOptions? options,
  required String projectId,
}) async {
  var firebaseApp = firebaseAdminSdk.initializeApp(
    options: FirebaseAppOptions(
      projectId: projectId,
      storageBucket: options?.storageBucket,
    ),
  );
  return initFirebaseServicesAdminSdk()
      .copyWith(firebaseApp: firebaseApp)
      .initSync();
}

class _FestenaoAdminFirebaseAdminSdk implements FestenaoAdminFirebase {
  @override
  String get name => 'admin sdk';

  @override
  Future<FirebaseContext> initWithServiceAccount(Map serviceAccountMap) =>
      festenaoInitFirebaseAdminSdkWithServiceAccount(
        serviceAccountMap: serviceAccountMap,
      );

  @override
  Future<FirebaseContext> initWithApplicationDefault(String projectId) =>
      festenaoInitFirebaseAdminSdkWithApplicationDefault(projectId: projectId);

  @override
  Future<List<String>?> listDocumentIds(
    Firestore firestore,
    String collectionPath,
  ) async {
    if (firestore is! FirestoreAdminSdk) {
      return null;
    }
    var refs = await firestore.nativeInstance
        .collection(collectionPath)
        .listDocuments();
    return refs.map((ref) => ref.id).toList();
  }
}

/// The admin sdk (io only): it also lists the documents that do not exist,
/// the ids that only hold sub collections.
final FestenaoAdminFirebase festenaoAdminFirebaseAdminSdk =
    _FestenaoAdminFirebaseAdminSdk();

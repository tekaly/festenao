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

class _FestenaoAdminFirebaseAdminSdk implements FestenaoAdminFirebase {
  @override
  String get name => 'admin sdk';

  @override
  Future<FirebaseContext> initWithServiceAccount(Map serviceAccountMap) =>
      festenaoInitFirebaseAdminSdkWithServiceAccount(
        serviceAccountMap: serviceAccountMap,
      );

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

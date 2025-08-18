import 'package:festenao_common/data/src/festenao/firebase/fb_context.dart';
import 'package:festenao_common/festenao_firebase_rest.dart';

Future<FbContext> initCompatV1FirebaseIo({
  String? rootPath,
  required Map serviceAccount,
  String? bucket,
}) async {
  //var client = httpClientFactory.newClient();
  var scopes = [
    ...firebaseBaseScopes,
    storageGoogleApisReadWriteScope,
    firestoreGoogleApisAuthDatastoreScope,
  ];

  var app = await firebaseRest.initializeAppWithServiceAccountMap(
    serviceAccount,
    scopes: scopes,
  );
  var firestore = firestoreServiceRest.firestore(app);
  var storage = storageServiceRest.storage(app);
  var auth = authServiceRest.auth(app);
  var appOptions = app.options;
  var projectId = app.options.projectId;
  return FbContext(
    app: app,
    auth: auth,
    projectId: projectId,
    firestore: firestore,
    firestoreService: firestoreServiceRest,
    storage: storage,
    storageBucket: bucket ?? '${appOptions.projectId}.appspot.com',
    firestoreRootPath: rootPath,
    storageRootPath: rootPath,
  );
}

// ignore_for_file: depend_on_referenced_packages

// ignore: unused_import

import 'package:festenao_admin_base_app/auth/auth.dart';
import 'package:tekartik_firebase_auth_flutter/auth_flutter.dart';
import 'package:tekartik_firebase_firestore_flutter/firestore_flutter.dart';
import 'package:tekartik_firebase_flutter/firebase_flutter.dart';
import 'package:tekartik_firebase_flutter_ui_auth/ui_auth.dart';
import 'package:tekartik_firebase_storage_flutter/storage_flutter.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

//import 'oauth_google.dart';

Future<FirebaseContext> initFestenaoAdminFirebaseFlutter({
  required FirebaseAppOptions firebaseAppOptions,
}) async {
  var firebase = firebaseFlutter;

  var context = await FirebaseServicesContext(
    appOptions: firebaseAppOptions,
    firebase: firebase,
    firestoreService: firestoreServiceFlutter,
    authService: authServiceFlutter,
    storageService: storageServiceFlutter,
  ).init();
  //await initAuthGoogle();
  await context.auth.webSetIndexedDbPersistence();

  globalAuthFlutterUiService = const FirebaseUiAuthServiceFlutter();
  return context;
}

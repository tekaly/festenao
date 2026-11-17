import 'package:firebase_core/firebase_core.dart'
    as native
    show FirebaseOptions;
import 'package:flutter/foundation.dart';
import 'package:idb_shim/sdb.dart' show SdbFactory;
import 'package:tekartik_firebase_auth_flutter/auth_flutter.dart';
import 'package:tekartik_firebase_auth_rest/auth_rest.dart';
import 'package:tekartik_firebase_firestore_flutter/firestore_flutter.dart';
import 'package:tekartik_firebase_flutter/firebase_flutter.dart';
import 'package:tekartik_firebase_flutter_ui_auth/ui_auth.dart';
import 'package:tekartik_firebase_functions_call_flutter/functions_call_flutter.dart';
import 'package:tekartik_firebase_storage/storage.dart' show StorageService;
import 'package:tkcms_common/tkcms_firebase.dart';

/// True where flutterfire is set up (the web): elsewhere (desktop) an app
/// reaches the same project through the rest apis
/// ([initFirebaseAuthFirestoreFunctionsRest]).
bool get firebaseAuthFirestoreFunctionsFlutterSupported => kIsWeb;

/// The auth, firestore and functions call (in [functionsCallRegion])
/// services of the project of [options], through flutterfire (the web).
///
/// The auth persists in indexed db, and the flutterfire sign in screens
/// (`firebaseUiAuthServiceFlutter`) are set up on it: email, and Google
/// with [googleWebClientId] when given.
///
/// [storageService] adds Storage (`storageServiceFlutter` of
/// tekartik_firebase_storage_flutter, which the app depends on): an app
/// storing files (synced media) passes it. The rest variant has Storage
/// already.
Future<FirebaseContext> initFirebaseAuthFirestoreFunctionsFlutter({
  required native.FirebaseOptions options,
  required String functionsCallRegion,
  String? googleWebClientId,
  StorageService? storageService,
}) async {
  var context = await FirebaseServicesContext(
    appOptions: firebaseFlutter.wrapOptions(options),
    firebase: firebaseFlutter,
    firestoreService: firestoreServiceFlutter,
    authService: firebaseAuthServiceFlutter,
    functionsCallService: firebaseFunctionsCallServiceFlutter,
    functionsCallRegion: functionsCallRegion,
    storageService: storageService,
  ).init();
  await context.auth.webSetIndexedDbPersistence();
  firebaseUiAuthServiceFlutter.configureProviders(
    firebaseAuth: context.auth,
    googleAuthClientId: googleWebClientId,
  );
  return context;
}

/// The same services of the project of [options] (the options of its web
/// app) through the rest apis (desktop: linux, macos, windows): the same
/// firestore, rules, users and functions as the web build.
///
/// The auth session is kept in the database [authDbName] of [sdbFactory],
/// so an anonymous user stays the same across restarts.
Future<FirebaseContext> initFirebaseAuthFirestoreFunctionsRest({
  required native.FirebaseOptions options,
  required String functionsCallRegion,
  required SdbFactory sdbFactory,
  String authDbName = 'firebase_auth_rest.db',
}) async {
  var services =
      (await initFirebaseServicesRest(
        appOptions: firebaseFlutter.wrapOptions(options),
      )).copyWith(
        authService: FirebaseAuthServiceRest(
          persistence: FirebaseRestAuthPersistenceOnPersistence(
            TekartikFirebasePersistenceSdb(
              sdbFactory: sdbFactory,
              dbName: authDbName,
            ),
          ),
        ),
        functionsCallRegion: functionsCallRegion,
      );
  return services.init();
}

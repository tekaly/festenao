// ignore_for_file: depend_on_referenced_packages

@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/api/festenao_api_fs_entity_client.dart';
import 'package:festenao_common/festenao_firebase_rest.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:http/http.dart' as http;
import 'package:tekartik_app_http/app_http.dart';
import 'package:tekartik_firebase_emulator/firebase_emulator.dart';
import 'package:tekartik_firebase_functions_call_http/functions_call_http.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_app.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_server.dart';

var defaultRegion = regionBelgium;
var emulatorService = FirebaseEmulatorService(path: '.');

Future<FirebaseEmulator> startServer(String projectId) async {
  var emulator = await emulatorService.start(
    options: FirebaseEmulatorOptions(
      onlyFunctions: true,
      onlyFirestore: true,
      debug: false,
      projectId: projectId,
    ),
  );
  return emulator;
}

class FestenaoTestServerEmulatorContext extends FestenaoTestServerContext {
  final FirebaseEmulator emulator;

  FestenaoTestServerEmulatorContext({
    required super.clientContext,
    required this.emulator,
    required super.ampService,
  });

  @override
  Future<void> close() async {
    await emulator.stop();
    await super.close();
  }
}

Future<FestenaoTestServerEmulatorContext> initEmulatorServerContext() async {
  // The emulator is entirely local (no real Firebase project involved): the
  // functions and Firestore emulators serve requests, no auth is needed for
  // any of the commands exercised here.
  var projectId = await emulatorService.getProjectId();
  var emulator = await startServer(projectId);
  var baseUri = 'http://localhost:5001/$projectId/$defaultRegion';
  var httpsApiUri = Uri.parse('$baseUri/$functionCommandDartV2Dev');
  var callableApiUri = Uri.parse('$baseUri/$callableFunctionCommandDartV2Dev');
  var ampUri = Uri.parse('$baseUri/ampdev');

  var callableApp = newFirebaseAppMemory(
    options: FirebaseAppOptions(projectId: projectId),
  );
  var functionsCall = firebaseFunctionsCallServiceHttp.functionsCall(
    callableApp,
    options: FirebaseFunctionsCallOptions(region: defaultRegion),
  );
  var apiService = FestenaoApiService(
    httpClientFactory: httpClientFactoryIo,
    httpsApiUri: httpsApiUri,
    callableApi: functionsCall.callableFromUri(callableApiUri),
    app: tkCmsAppDev,
  );
  await apiService.initClient();

  var ampService = FestenaoAmpService(
    httpClientFactory: httpClientFactoryIo,
    httpsAmpUri: ampUri,
  );
  await ampService.initClient();

  return FestenaoTestServerEmulatorContext(
    emulator: emulator,
    clientContext: FestenaoTestClientContext(apiService: apiService),
    ampService: ampService,
  );
}

var authEmulatorHost = 'localhost';
var authEmulatorPort = 9099;
var firestoreEmulatorHost = 'localhost';
var firestoreEmulatorPort = 8080;

/// The "app" (top) entity id used by [FfApp] (its default `app` name).
var testAppId = 'festenao';

/// Writes [fields] at [path] (relative to the database root, e.g.
/// `app/festenao`) directly against the Firestore emulator's REST API,
/// authenticated as [idToken].
///
/// This goes straight to the emulator's REST endpoint with the caller's own
/// ID token rather than through `FirestoreRest.useFirestoreEmulator()`:
/// that helper always sends `Authorization: Bearer owner` (see
/// `_FirestoreEmulatorClient` in `firestore_rest_impl.dart`), i.e. it always
/// acts as the emulator admin/owner and bypasses `firestore.rules`
/// entirely -- unusable for testing per-user rule enforcement.
@Deprecated('user firestore(Rest).set() instead')
Future<http.Response> firestoreEmulatorRestSet({
  required String projectId,
  required String path,
  required String idToken,
  required Map<String, String> fields,
}) {
  var uri = Uri.parse(
    'http://$firestoreEmulatorHost:$firestoreEmulatorPort/v1/projects/'
    '$projectId/databases/(default)/documents/$path',
  );
  return http.patch(
    uri,
    headers: {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'fields': fields.map(
        (key, value) => MapEntry(key, {'stringValue': value}),
      ),
    }),
  );
}

/// Reads the document at [path], authenticated as [idToken]. See
/// [firestoreEmulatorRestSet] for why this bypasses `FirestoreRest`.
@Deprecated('user firestore(Rest).put() instead')
Future<http.Response> firestoreEmulatorRestGet({
  required String projectId,
  required String path,
  required String idToken,
}) {
  var uri = Uri.parse(
    'http://$firestoreEmulatorHost:$firestoreEmulatorPort/v1/projects/'
    '$projectId/databases/(default)/documents/$path',
  );
  return http.get(uri, headers: {'Authorization': 'Bearer $idToken'});
}

/// The signed-in user's raw ID token.
///
/// [UserInfoWithIdToken.getIdToken] isn't implemented by the built-in
/// email/password provider, so this reaches for the concrete REST
/// credential's `idToken` getter instead (not re-exported by the public
/// `auth_rest.dart` facade, hence the dynamic access).
String userCredentialIdToken(UserCredential credential) {
  // ignore: avoid_dynamic_calls
  return (credential as dynamic).idToken as String;
}

Future<void> main() async {
  debugWebServices = true;
  debugFirestoreRest = true;
  var emulatorSupported = await emulatorService.isSupported();
  if (!emulatorSupported) {
    test('Firebase emulator not supported', () {
      stderr.writeln('Firebase emulator not supported');
    });
    return;
  }

  group('app admin access', () {
    late FirebaseEmulator emulator;
    late String projectId;
    late Uri httpsApiUri;
    late FirebaseAuthRest auth;
    late FirestoreRest firestore;

    setUpAll(() async {
      projectId = await emulatorService.getProjectId();
      emulator = await emulatorService.start(
        options: FirebaseEmulatorOptions(
          onlyFunctions: true,
          onlyFirestore: true,
          onlyAuth: true,
          debug: false,
          projectId: projectId,
        ),
      );
      httpsApiUri = Uri.parse(
        'http://localhost:5001/$projectId/$defaultRegion/$functionCommandDartV2Dev',
      );

      // A rest client, backed by a real signed-in Firebase Auth user, used
      // to obtain per-user ID tokens for the direct (rules-enforced)
      // Firestore REST calls below.
      var restApp = await firebaseRest.initializeAppAsync(
        options: FirebaseAppOptions(projectId: projectId, apiKey: 'dummy'),
      );
      auth = firebaseAuthServiceRest.auth(restApp);
      firestore = firestoreServiceRest.firestore(restApp);
      await auth.useAuthEmulator(authEmulatorHost, authEmulatorPort);
      await firestore.useFirestoreEmulator(
        firestoreEmulatorHost,
        firestoreEmulatorPort,
      );
    });

    tearDownAll(() async {
      await auth.app.delete();
      await emulator.stop();
    });

    test('admin can write, unrelated user cannot', () async {
      // Sign in the future app admin.
      var adminCredential = await auth.signInOrUpWithEmailAndPassword(
        email: 'admin@festenao-dartff-test.local',
        password: 'test1234',
      );
      expect(auth.currentUser, isNotNull);
      var adminUid = adminCredential.user.uid;

      // Bootstrap the "app" (top) entity and grant this user admin access to
      // it, using the cloud function's entity create command: this runs
      // through the admin SDK server side, which bypasses security rules --
      // the only way to create the very first admin for an entity.
      initTkCmsFsBuilders();
      initFestenaoFsEntityApiBuilders<TkCmsFsApp>();
      var bootstrapApiService = FestenaoApiService(
        httpClientFactory: httpClientFactoryIo,
        httpsApiUri: httpsApiUri,
      )..userIdOrNull = adminUid;

      var appApiClient = FestenaoApiFsEntityClient<TkCmsFsApp>(
        apiService: bootstrapApiService,
        entityAccess: TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsApp>(
          entityCollectionInfo: tkCmsFsAppCollectionInfo,
          firestore: firestore, // Not used for access
        ),
      );

      // Delete if it exists...
      await firestore.doc('app/$testAppId').delete();

      await appApiClient.createEntity(
        entity: TkCmsFsApp(),
        entityId: testAppId,
      );

      // Signed in as the admin, a direct Firestore write (subject to
      // security rules, unlike the admin SDK above) must be allowed.
      /*
      var adminSetResponse = await firestoreEmulatorRestSet(
        projectId: projectId,
        path: 'app/$testAppId',
        idToken: adminIdToken,
        fields: {'probe': 'admin-write-ok'},
      );
      expect(adminSetResponse.statusCode, 200, reason: adminSetResponse.body);*/
      var docRef = firestore.doc('app/$testAppId');
      await docRef.set({'probe': 'admin-write-ok'});

      var snapshot = await docRef.get();
      var data = snapshot.data;
      expect(data, {'probe': 'admin-write-ok'});

      // A different, unrelated user has no access grant on this entity: a
      // direct Firestore write must be rejected by the security rules.
      await auth.signOut();
      expect(auth.currentUser, isNull);
      await auth.signInOrUpWithEmailAndPassword(
        email: 'stranger@festenao-dartff-test.local',
        password: 'test1234',
      );
      expect(auth.currentUser, isNotNull);
      try {
        await docRef.set({'probe': 'stranger-write'});
        fail('should fail');
      } on FirestoreException catch (e) {
        expect(e.code, FirestoreErrorCode.permissionDenied);
      }
    });
  }, timeout: Timeout(Duration(minutes: 5)));

  group('emulator_test', () {
    testFestenaoServerGroup(
      initEmulatorServerContext,
      noSignIn: true,
      noObjectStorage: true,
    );
  }, timeout: Timeout(Duration(minutes: 5)));
}

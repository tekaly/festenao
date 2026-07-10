@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/api/festenao_api_fs_entity_client.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/festenao_firebase_rest.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/test/festenao_doc_test_server_test_runner.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:tekartik_firebase_emulator/firebase_emulator.dart';
import 'package:tekartik_firebase_functions_call_http/functions_call_http.dart';
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
      onlyAuth: true,
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

  // A rest client, backed by a real signed-in Firebase Auth user, used
  // to obtain per-user ID tokens for the direct (rules-enforced)
  // Firestore REST calls below.
  var restApp = await firebaseRest.initializeAppAsync(
    options: FirebaseAppOptions(projectId: projectId, apiKey: 'dummy'),
  );
  var auth = firebaseAuthServiceRest.auth(restApp);
  var firestore = firestoreServiceRest.firestore(restApp);
  var functionsCall = firebaseFunctionsCallServiceHttp.functionsCall(
    restApp,
    options: FirebaseFunctionsCallOptions(region: defaultRegion),
  );
  var fbContext = FirebaseContext(
    firebaseApp: restApp,
    auth: auth,
    firestore: firestore,
    functionsCall: functionsCall,
  );
  await fbContext.useEmulator();

  var apiService = FestenaoApiService(
    httpsApiUri: httpsApiUri,
    callableApi: functionsCall.callableFromUri(callableApiUri),
    app: tkCmsAppDev,
  );
  await apiService.initClient();

  var ampService = FestenaoAmpService(httpsAmpUri: ampUri);
  await ampService.initClient();
  var fsDatabase = FestenaoFirestoreDatabase(
    firebaseContext: fbContext,
    flavorContext: AppFlavorContext(
      flavorContext: FlavorContext.dev,
      app: apiService.app,
    ),
  );
  var projectApiClient = FestenaoApiFsEntityClient(
    apiService: apiService,
    entityAccess: fsDatabase.projectDb,
  );
  return FestenaoTestServerEmulatorContext(
      emulator: emulator,
      clientContext: FestenaoTestClientContext(
        apiService: apiService,
        firebaseApp: restApp,
        credentials: emulatorCredentials,
      ),
      ampService: ampService,
    )
    ..ffContext = fbContext
    ..projectApiClient = projectApiClient
    ..fsDatabase = fsDatabase;
}

const emulatorCredentials = TkCmsEmailPasswordCredentials(
  email: 'festenao@gmail.com',
  password: 'test1234',
);

var authEmulatorHost = 'localhost';
var authEmulatorPort = 9099;
var firestoreEmulatorHost = 'localhost';
var firestoreEmulatorPort = 8080;

/// The "app" (top) entity id used by [FfApp] (its default `app` name).
var testAppId = 'festenao';

void adminAccessTestRunner(
  Future<FestenaoTestClientContext> Function() contextBuilder,
) {
  late FestenaoTestClientContext testContext;
  late FirebaseAuth auth;
  late Uri httpsApiUri;
  late final firestore = testContext.firestore!;

  setUp(() async {
    testContext = await contextBuilder();
    auth = testContext.firebaseAuth!;
    httpsApiUri = testContext.apiService.httpsApiUri!;
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
    var bootstrapApiService = FestenaoApiService(httpsApiUri: httpsApiUri)
      ..userIdOrNull = adminUid;

    var appApiClient = FestenaoApiFsEntityClient<TkCmsFsApp>(
      apiService: bootstrapApiService,
      entityAccess: TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsApp>(
        entityCollectionInfo: tkCmsFsAppCollectionInfo,
        firestore: firestore, // Not used for access
      ),
    );

    // Delete if it exists...
    await firestore.doc('app/$testAppId').delete();

    await appApiClient.createEntity(entity: TkCmsFsApp(), entityId: testAppId);

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
  late FestenaoTestServerEmulatorContext testContext;
  late final firestore = testContext.clientContext.firestore!;
  group('admin access', () {
    setUpAll(() async {
      testContext = await initEmulatorServerContext();
    });

    group('emulator_test', () {
      adminAccessTestRunner(() async => testContext.clientContext);
      testFestenaoServerGroup(
        () async => testContext,

        noObjectStorage: true,

        options: TestFestenaoServerGroupOptions(addFirestoreDoc: true),
      );
      testFestenaoDocServerGroup(() async => testContext);
    }, timeout: Timeout(Duration(minutes: 5)));
    tearDownAll(() async {
      await testContext.close();
      await firestore.app.delete();
    });
  }, timeout: Timeout(Duration(minutes: 5)));
}

// ignore: unused_import
import 'package:dev_test/test.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/api/festenao_api_fs_entity_client.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/festenao_http.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:tekartik_firebase_emulator/firebase_emulator.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_common/tkcms_server.dart';

import 'festenao_test_server_test_runner.dart';

/// Festenao test server emulator context.
class FestenaoTestServerEmulatorContext extends FestenaoTestServerContext {
  /// Emulator.
  final FirebaseEmulator emulator;

  /// Constructor for [FestenaoTestServerEmulatorContext].
  FestenaoTestServerEmulatorContext({
    required super.clientContext,
    required this.emulator,
    required super.ampService,
  });

  @override
  Future<void> close() async {
    if (closed) {
      return;
    }
    await emulator.stop();
    await super.close();
  }
}

/// Emulator options
var emulatorTestRunnerOptions = FirebaseEmulatorOptions(
  onlyFunctions: true,
  onlyFirestore: true,
  onlyAuth: true,
  debug: false,
);

/// Credentials of the user the emulator context signs in as its owner.
///
/// Needed by the test runners driving the api as an entity admin (see
/// [FestenaoTestClientContext.credentials]), the emulator auth accepts any
/// email/password pair.
const emulatorTestServerCredentials = TkCmsEmailPasswordCredentials(
  email: 'owner@festenao-dartff-test.local',
  password: 'test1234',
);

/// Emulator context
Future<FestenaoTestServerEmulatorContext> initEmulatorServerContext({
  required String path,
  required String region,
  required String appId,
}) async {
  // The emulator is entirely local (no real Firebase project involved): the
  // functions and Firestore emulators serve requests, no auth is needed for
  // any of the commands exercised here.
  var emulatorService = FirebaseEmulatorService(path: path);
  var projectId = await emulatorService.getProjectId();
  var emulator = await emulatorService.start(
    options: emulatorTestRunnerOptions,
  );
  var baseUri = 'http://localhost:5001/$projectId/$region';
  var httpsApiUri = Uri.parse('$baseUri/$functionCommandDartV2Dev');
  var callableApiUri = Uri.parse('$baseUri/$callableFunctionCommandDartV2Dev');
  var ampUri = Uri.parse('$baseUri/ampdev');

  var fbContext = await (await initFirebaseServicesRest(
    appOptions: FirebaseAppOptions(projectId: projectId, apiKey: 'dummy'),
  )).init();
  await fbContext.useEmulator();

  var functionsCallable = fbContext.functionsCall.callableFromUri(
    callableApiUri,
  );
  var apiService = FestenaoApiService(
    httpClientFactory: httpClientFactoryIo,
    httpsApiUri: httpsApiUri,
    callableApi: functionsCallable,
    app: appId,
  );
  await apiService.initClient();

  var ampService = FestenaoAmpService(
    httpClientFactory: httpClientFactoryIo,
    httpsAmpUri: ampUri,
  );
  await ampService.initClient();

  // The client side view of the database, rooted like the deployed functions
  // one: same app id, same (dev) flavor as `FfApp`.
  var fsDatabase = FestenaoFirestoreDatabase(
    firebaseContext: fbContext,
    flavorContext: AppFlavorContext(
      flavorContext: FlavorContext.dev,
      app: appId,
    ),
  );
  var projectApiClient = FestenaoApiFsEntityClient<FsProject>(
    apiService: apiService,
    entityAccess: fsDatabase.projectDb,
  );

  return FestenaoTestServerEmulatorContext(
      emulator: emulator,
      clientContext: FestenaoTestClientContext(
        apiService: apiService,
        firebaseApp: fbContext.firebaseApp,
        credentials: emulatorTestServerCredentials,
      ),
      ampService: ampService,
    )
    ..projectApiClient = projectApiClient
    ..fsDatabase = fsDatabase;
}

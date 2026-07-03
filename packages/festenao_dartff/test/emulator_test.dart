// ignore_for_file: depend_on_referenced_packages

@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:tekartik_app_http/app_http.dart';
import 'package:tekartik_firebase_emulator/firebase_emulator.dart';
import 'package:tekartik_firebase_functions_call_http/functions_call_http.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_app.dart';
import 'package:tkcms_common/tkcms_common.dart';
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

Future<void> main() async {
  debugWebServices = true;
  var emulatorSupported = await emulatorService.isSupported();
  if (!emulatorSupported) {
    stderr.writeln('Firebase emulator not supported');
    return;
  }
  group('emulator_test', () {
    testFestenaoServerGroup(
      initEmulatorServerContext,
      noSignIn: true,
      noObjectStorage: true,
    );
  }, timeout: Timeout(Duration(minutes: 5)));
}

@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_common/festenao_firebase_rest.dart';
import 'package:festenao_common/server/festenao_server_cms.dart';
import 'package:festenao_demo/festenao_demo_cms.dart';
import 'package:tekartik_firebase_emulator/firebase_emulator.dart';
import 'package:tekartik_firebase_functions_call_http/functions_call_http.dart';
import 'package:tekartik_http_io/http_client_io.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_server.dart';

var emulatorService = FirebaseEmulatorService(path: '.');

/// The app of the dev `FfApp` of functions/bin/server.dart (its default).
const _app = 'festenao';

/// The cms functions of functions/bin/server.dart, run by the emulator:
///
/// - `cmsdemo`, the hard coded demo site;
/// - `cmsdev`, the site of a project whose synced content holds the demo
///   pages.
Future<void> main() async {
  if (!await emulatorService.isSupported()) {
    test('Firebase emulator not supported', () {
      stderr.writeln('Firebase emulator not supported');
    });
    return;
  }
  late FirebaseEmulator emulator;
  late FirebaseContext fbContext;
  late Uri functionsUri;
  var client = httpClientFactoryIo.newClient();

  setUpAll(() async {
    var projectId = await emulatorService.getProjectId();
    emulator = await emulatorService.start(
      options: FirebaseEmulatorOptions(
        onlyFunctions: true,
        onlyFirestore: true,
        debug: false,
        projectId: projectId,
      ),
    );
    functionsUri = Uri.parse(
      'http://localhost:5001/$projectId/$regionBelgium/',
    );

    // A rest firestore bypassing the rules (the emulator owner), writing
    // the demo project as the server sees it.
    var restApp = await firebaseRest.initializeAppAsync(
      options: FirebaseAppOptions(projectId: projectId, apiKey: 'dummy'),
    );
    fbContext = FirebaseContext(
      firebaseApp: restApp,
      firestore: firestoreServiceRest.firestore(restApp),
    );
    await fbContext.useEmulator(firestoreOwner: true);
  });

  tearDownAll(() async {
    client.close();
    await emulator.stop();
    await fbContext.firebaseApp.delete();
  });

  Future<Response> get(String path) => client.get(functionsUri.resolve(path));

  group('cmsdemo', () {
    test('index and pages', () async {
      var index = await get('$festenaoCmsDemoFunction/');
      expect(index.statusCode, 200, reason: index.body);
      expect(index.headers['content-type'], cmsContentTypeHtml);
      expect(index.body, contains(demoCmsSiteName));
      expect(index.body, contains('About the festival'));

      var page = await get('$festenaoCmsDemoFunction/page/about');
      expect(page.statusCode, 200, reason: page.body);
      expect(page.body, contains('<h1>About the festival</h1>'));

      var event = await get(
        '$festenaoCmsDemoFunction/page/opening-night-concert',
      );
      expect(event.body, contains('"@type":"Event"'));

      var draft = await get('$festenaoCmsDemoFunction/page/line-up-2027');
      expect(draft.statusCode, 404);
    });
  });

  group('cmsdev', () {
    test('the site of the demo project', () async {
      var project = await fillDemoCmsProject(
        firestore: fbContext.firestore,
        app: _app,
      );
      var siteUrl =
          '$festenaoCmsFunctionDev/${project.projectId}/${project.dataId}/';
      var index = await get(siteUrl);
      expect(index.statusCode, 200, reason: index.body);
      expect(index.body, contains(demoCmsSiteName));
      expect(index.body, contains('About the festival'));

      var page = await get('${siteUrl}page/about');
      expect(page.statusCode, 200, reason: page.body);
      expect(page.body, contains('<h1>About the festival</h1>'));

      var unknown = await get(
        '$festenaoCmsFunctionDev/unknown/${project.dataId}/',
      );
      expect(unknown.statusCode, 404);
    });
  });
}

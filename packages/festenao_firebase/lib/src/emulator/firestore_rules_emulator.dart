import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:tekartik_firebase_emulator/firebase_emulator.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

import '../rules/rules_builder.dart';

/// Default project id of a rules emulator: a `demo-` project needs no
/// firebase login and never reaches a real project.
const firestoreRulesEmulatorDefaultProjectId = 'demo-festenao-rules';

/// Default auth emulator port.
const firestoreRulesEmulatorDefaultAuthPort = 9099;

/// Default firestore emulator port.
const firestoreRulesEmulatorDefaultFirestorePort = 8080;

/// Runs the firestore and auth emulators on a generated firebase folder
/// carrying the rules under test, and hands out rest clients: rules enforced
/// ones signed in through the auth emulator, and an owner one bypassing the
/// rules (the emulator treats the `owner` bearer token as an admin request,
/// which is how the initial content is seeded).
///
/// ```dart
/// var emulator = await FirestoreRulesEmulator.start(rules: myRules);
/// var user = await emulator.newUserContext();      // rules enforced
/// var admin = await emulator.newOwnerContext();    // bypasses the rules
/// await admin.firestore.doc('app/x').set({'seed': true});
/// await user.auth.signInOrUpWithEmailAndPassword(email: ..., password: ...);
/// await user.firestore.doc('app/x').get();         // checked by the rules
/// await emulator.stop();
/// ```
///
/// The emulators are started once per folder; when they are already running
/// (started by hand with `tool/start_rules_emulator.dart`, or by a previous
/// context of the same process) the rules are hot loaded through the
/// emulator api instead.
class FirestoreRulesEmulator {
  /// The project id.
  final String projectId;

  /// The firebase folder (`.firebaserc`, `firebase.json`, `firestore.rules`).
  final String path;

  /// The started emulator (or the already running one).
  final FirebaseEmulator emulator;

  /// Emulator host.
  final String host;

  /// Firestore emulator port.
  final int firestorePort;

  /// Auth emulator port.
  final int authPort;

  final _client = http.Client();
  final _contexts = <FirebaseContext>[];
  var _appCount = 0;

  FirestoreRulesEmulator._({
    required this.projectId,
    required this.path,
    required this.emulator,
    required this.host,
    required this.firestorePort,
    required this.authPort,
  });

  /// The firebase.json content of a rules only project.
  static Map<String, Object?> firebaseJson({
    int firestorePort = firestoreRulesEmulatorDefaultFirestorePort,
    int authPort = firestoreRulesEmulatorDefaultAuthPort,
  }) => {
    'emulators': {
      'firestore': {'port': firestorePort},
      'auth': {'port': authPort},
      'ui': {'enabled': false},
      'singleProjectMode': true,
    },
    'firestore': {
      'database': '(default)',
      'rules': 'firestore.rules',
      'indexes': 'firestore.indexes.json',
    },
  };

  /// Writes the firebase folder at [path] for [projectId] with [rulesText]
  /// (creating it when needed; existing `firebase.json`/`.firebaserc` are
  /// overwritten only when [force] is true or missing).
  static Future<void> writeFirebaseFolder({
    required String path,
    required String projectId,
    required String rulesText,
    bool force = false,
    int firestorePort = firestoreRulesEmulatorDefaultFirestorePort,
    int authPort = firestoreRulesEmulatorDefaultAuthPort,
  }) async {
    var dir = Directory(path);
    await dir.create(recursive: true);
    Future<void> writeIfNeeded(String name, String content) async {
      var file = File(p.join(path, name));
      if (force || !file.existsSync()) {
        await file.writeAsString(content);
      }
    }

    const encoder = JsonEncoder.withIndent('  ');
    await writeIfNeeded(
      '.firebaserc',
      encoder.convert({
        'projects': {'default': projectId},
      }),
    );
    await writeIfNeeded(
      'firebase.json',
      encoder.convert(
        firebaseJson(firestorePort: firestorePort, authPort: authPort),
      ),
    );
    await writeIfNeeded(
      'firestore.indexes.json',
      encoder.convert({'indexes': <Object>[], 'fieldOverrides': <Object>[]}),
    );
    await File(p.join(path, 'firestore.rules')).writeAsString(rulesText);
  }

  /// Whether the emulator can run here (firebase cli installed, or already
  /// running with auth and firestore).
  static Future<bool> isSupported({String? path}) async {
    var service = FirebaseEmulatorService(
      path: path ?? defaultPath(firestoreRulesEmulatorDefaultProjectId),
    );
    try {
      await writeFirebaseFolder(
        path: service.path,
        projectId: firestoreRulesEmulatorDefaultProjectId,
        rulesText: FirestoreRules().toRulesText(),
      );
      return await service.isSupported(
        options: FirebaseEmulatorOptions(onlyAuth: true, onlyFirestore: true),
      );
    } catch (_) {
      return false;
    }
  }

  /// The default firebase folder of [projectId]:
  /// `.dart_tool/festenao_firebase/emulator/<projectId>` in the current
  /// directory.
  static String defaultPath(String projectId) =>
      p.join('.dart_tool', 'festenao_firebase', 'emulator', projectId);

  /// Starts (or reuses) the auth and firestore emulators with [rules] (or
  /// [rulesText]).
  ///
  /// [path] is the firebase folder, generated under `.dart_tool` by default.
  static Future<FirestoreRulesEmulator> start({
    FirestoreRules? rules,
    String? rulesText,
    String projectId = firestoreRulesEmulatorDefaultProjectId,
    String? path,
    String host = 'localhost',
    int firestorePort = firestoreRulesEmulatorDefaultFirestorePort,
    int authPort = firestoreRulesEmulatorDefaultAuthPort,
    bool debug = false,
    String? persistPath,
  }) async {
    rulesText ??= rules!.toRulesText();
    path ??= defaultPath(projectId);
    await writeFirebaseFolder(
      path: path,
      projectId: projectId,
      rulesText: rulesText,
      firestorePort: firestorePort,
      authPort: authPort,
      force: true,
    );
    var service = FirebaseEmulatorService(path: path);
    var emulator = await service.start(
      options: FirebaseEmulatorOptions(
        projectId: projectId,
        onlyAuth: true,
        onlyFirestore: true,
        debug: debug,
        persistPath: persistPath,
      ),
    );
    var rulesEmulator = FirestoreRulesEmulator._(
      projectId: projectId,
      path: path,
      emulator: emulator,
      host: host,
      firestorePort: firestorePort,
      authPort: authPort,
    );
    if (emulator is FirebaseRunningEmulator) {
      // Already running: make sure it runs our rules.
      await rulesEmulator.loadRules(rulesText);
    }
    return rulesEmulator;
  }

  Uri _firestoreUri(String path) =>
      Uri.parse('http://$host:$firestorePort/$path');

  Uri _authUri(String path) => Uri.parse('http://$host:$authPort/$path');

  static const _ownerHeaders = {
    'Authorization': 'Bearer owner',
    'Content-Type': 'application/json',
  };

  void _check(http.Response response, String what) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        '$what failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// Hot loads [rulesText] (or [rules]) in the running firestore emulator.
  Future<void> loadRules(String? rulesText, {FirestoreRules? rules}) async {
    rulesText ??= rules!.toRulesText();
    var response = await _client.put(
      _firestoreUri('emulator/v1/projects/$projectId:securityRules'),
      headers: _ownerHeaders,
      body: jsonEncode({
        'rules': {
          'files': [
            {'name': 'firestore.rules', 'content': rulesText},
          ],
        },
      }),
    );
    _check(response, 'loadRules');
  }

  /// Deletes every document of the emulator database.
  Future<void> clearFirestore() async {
    var response = await _client.delete(
      _firestoreUri(
        'emulator/v1/projects/$projectId/databases/(default)/documents',
      ),
      headers: _ownerHeaders,
    );
    _check(response, 'clearFirestore');
  }

  /// Deletes every account of the auth emulator.
  Future<void> clearAuth() async {
    var response = await _client.delete(
      _authUri('emulator/v1/projects/$projectId/accounts'),
      headers: _ownerHeaders,
    );
    _check(response, 'clearAuth');
  }

  /// Sets the custom claims of the user [uid] (`request.auth.token.<claim>`)
  /// through the auth emulator admin api; null clears them.
  ///
  /// The claims land in the next id token: the user has to sign in again (or
  /// refresh its token) for the rules to see them.
  Future<void> setCustomUserClaims(
    String uid,
    Map<String, Object?>? claims,
  ) async {
    var response = await _client.post(
      _authUri(
        'identitytoolkit.googleapis.com/v1/projects/$projectId/accounts:update',
      ),
      headers: _ownerHeaders,
      body: jsonEncode({
        'localId': uid,
        'customAttributes': jsonEncode(claims ?? <String, Object?>{}),
      }),
    );
    _check(response, 'setCustomUserClaims');
  }

  /// Looks up an account by [email] through the auth emulator admin api,
  /// returns its `localId` (uid) or null.
  Future<String?> getUidByEmail(String email) async {
    var response = await _client.post(
      _authUri(
        'identitytoolkit.googleapis.com/v1/projects/$projectId/accounts:lookup',
      ),
      headers: _ownerHeaders,
      body: jsonEncode({
        'email': [email],
      }),
    );
    _check(response, 'getUidByEmail');
    var map = jsonDecode(response.body) as Map;
    var users = map['users'] as List?;
    if (users == null || users.isEmpty) {
      return null;
    }
    return (users.first as Map)['localId'] as String?;
  }

  Future<FirebaseContext> _newContext({
    required bool owner,
    String? name,
  }) async {
    var context = await (await initFirebaseServicesRest(
      appOptions: FirebaseAppOptions(projectId: projectId, apiKey: 'dummy'),
    )).init(name: name ?? '${owner ? 'owner' : 'user'}_${++_appCount}');
    await context.useEmulator(firestoreOwner: owner);
    _contexts.add(context);
    return context;
  }

  /// A rest context whose firestore is subject to the rules, as the user
  /// signed in through its auth (anonymous until then).
  Future<FirebaseContext> newUserContext({String? name}) =>
      _newContext(owner: false, name: name);

  /// A rest context whose firestore bypasses the rules (emulator owner).
  Future<FirebaseContext> newOwnerContext({String? name}) =>
      _newContext(owner: true, name: name);

  /// Closes the contexts and stops the emulator (no-op when it was already
  /// running before [start]).
  Future<void> stop() async {
    for (var context in _contexts) {
      try {
        await context.close();
      } catch (_) {}
    }
    _contexts.clear();
    _client.close();
    await emulator.stop();
  }
}

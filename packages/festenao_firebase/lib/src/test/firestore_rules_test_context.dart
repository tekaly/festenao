import 'dart:async';

import 'package:tekartik_firebase_auth_sembast/auth_sembast.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

import '../emulator/firestore_rules_emulator.dart';
import '../rules/rules_builder.dart';
import '../sim/rules_enforced_firestore.dart';

/// Password of every test user (the auth emulator and the memory auth accept
/// any).
const firestoreRulesTestPassword = 'test1234';

/// What a rules test needs, provided by the simulator or by the emulator:
/// a rules enforced [firestore] acting as the user signed in [auth], an
/// [adminFirestore] bypassing the rules to seed data, and the rules under
/// test ([setRules]).
abstract class FirestoreRulesTestContext {
  /// Rules enforced firestore, acting as the current user of [auth]
  /// (anonymous when signed out).
  Firestore get firestore;

  /// Bypasses the rules (seeding and checks).
  Firestore get adminFirestore;

  /// The auth of [firestore]: sign in/out changes who [firestore] acts as.
  FirebaseAuth get auth;

  /// True when this is the emulator (a few behaviors differ: token refresh).
  bool get isEmulator;

  /// Replaces the rules under test.
  Future<void> setRules(FirestoreRules rules);

  /// True when [setRulesText] is supported (the emulator only: the simulator
  /// needs the rules object, there is no parser).
  bool get supportsRulesText => false;

  /// Replaces the rules under test with a raw rules file text.
  Future<void> setRulesText(String rulesText) =>
      throw UnsupportedError('Rules text not supported');

  /// Sets the custom claims of [uid]; the user has to sign in again for them
  /// to be seen by the rules ([signInOrUp] after this call).
  Future<void> setCustomUserClaims(String uid, Map<String, Object?>? claims);

  /// Releases the resources.
  Future<void> close();

  /// Signs in (creating it if needed) the user [email], returns its uid.
  Future<String> signInOrUp(String email) async {
    var credential = await auth.signInOrUpWithEmailAndPassword(
      email: email,
      password: firestoreRulesTestPassword,
    );
    return credential.user.uid;
  }

  /// Signs out.
  Future<void> signOut() => auth.signOut();
}

/// The simulator backed context: memory firestore and memory auth.
class FirestoreRulesSimTestContext extends FirestoreRulesTestContext {
  /// The simulator (rules, auth binding, custom claims).
  final FirestoreRulesSimulator simulator;

  @override
  final Firestore adminFirestore;

  @override
  final FirebaseAuth auth;

  @override
  late final Firestore firestore = simulator.enforce(adminFirestore);

  /// Creates a context over an existing [adminFirestore] and [auth].
  FirestoreRulesSimTestContext({
    required FirestoreRules rules,
    required this.adminFirestore,
    required this.auth,
    bool debug = false,
  }) : simulator = FirestoreRulesSimulator(
         rules: rules,
         auth: auth,
         debug: debug,
       );

  /// Creates a context with a fresh memory firebase app.
  static Future<FirestoreRulesSimTestContext> create({
    required FirestoreRules rules,
    String projectId = 'rules-sim',
    bool debug = false,
  }) async {
    var firebase = FirebaseLocal();
    var app = await firebase.initializeAppAsync(
      options: FirebaseAppOptions(projectId: projectId),
    );
    var firestore = newFirestoreServiceMemory().firestore(app);
    var auth = newFirebaseAuthServiceMemory().auth(app);
    return FirestoreRulesSimTestContext(
      rules: rules,
      adminFirestore: firestore,
      auth: auth,
      debug: debug,
    );
  }

  @override
  bool get isEmulator => false;

  @override
  Future<void> setRules(FirestoreRules rules) async {
    simulator.rules = rules;
  }

  @override
  Future<void> setCustomUserClaims(
    String uid,
    Map<String, Object?>? claims,
  ) async {
    simulator.setCustomUserClaims(uid, claims);
  }

  @override
  Future<void> close() async {
    await adminFirestore.app.delete();
  }
}

/// The emulator backed context: rest clients on the auth and firestore
/// emulators, the admin one sent as the emulator owner.
class FirestoreRulesEmulatorTestContext extends FirestoreRulesTestContext {
  /// The emulator.
  final FirestoreRulesEmulator emulator;

  /// The rules enforced context.
  final FirebaseContext userContext;

  /// The owner context.
  final FirebaseContext ownerContext;

  /// Creates the context, see [create].
  FirestoreRulesEmulatorTestContext({
    required this.emulator,
    required this.userContext,
    required this.ownerContext,
  });

  /// Starts (or reuses) the emulator with [rules] and creates the contexts.
  static Future<FirestoreRulesEmulatorTestContext> create({
    required FirestoreRules rules,
    String projectId = firestoreRulesEmulatorDefaultProjectId,
    String? path,
    bool debug = false,
  }) async {
    var emulator = await FirestoreRulesEmulator.start(
      rules: rules,
      projectId: projectId,
      path: path,
      debug: debug,
    );
    var userContext = await emulator.newUserContext();
    var ownerContext = await emulator.newOwnerContext();
    return FirestoreRulesEmulatorTestContext(
      emulator: emulator,
      userContext: userContext,
      ownerContext: ownerContext,
    );
  }

  @override
  Firestore get firestore => userContext.firestore;

  @override
  Firestore get adminFirestore => ownerContext.firestore;

  @override
  FirebaseAuth get auth => userContext.auth;

  @override
  bool get isEmulator => true;

  @override
  Future<void> setRules(FirestoreRules rules) =>
      emulator.loadRules(rules.toRulesText());

  @override
  bool get supportsRulesText => true;

  @override
  Future<void> setRulesText(String rulesText) => emulator.loadRules(rulesText);

  @override
  Future<void> setCustomUserClaims(String uid, Map<String, Object?>? claims) =>
      emulator.setCustomUserClaims(uid, claims);

  @override
  Future<void> close() => emulator.stop();
}

/// Builds a [FirestoreRulesTestContext].
typedef FirestoreRulesTestContextBuilder =
    FutureOr<FirestoreRulesTestContext> Function();

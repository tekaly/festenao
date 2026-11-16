import 'package:tekartik_firebase_ui_auth/ui_auth.dart'
    show FirebaseUiAuthService;
import 'package:tkcms_common/tkcms_firebase.dart' show FirebaseContext;

/// How an app reaches firebase.
enum FestenaoFirebaseMode {
  /// Native flutterfire (the web).
  flutter,

  /// The rest apis (desktop), same project.
  rest,

  /// Everything in memory with the server in process: the demo.
  memory,
}

/// The firebase services an app runs against ([context]: auth, firestore,
/// the functions call), how they were reached ([mode]), the sign in ui, the
/// api service [A] of the app and, in the demo, its in memory backend [B].
///
/// An app names its own:
/// `typedef MyAppFirebase = FestenaoAppFirebase<MyApi, MyBackend>`.
class FestenaoAppFirebase<A, B> {
  /// Auth, firestore, functions call.
  final FirebaseContext context;

  /// How they were reached.
  final FestenaoFirebaseMode mode;

  /// The sign in ui: flutterfire's (email, Google) on the web, the basic
  /// email/password one elsewhere.
  final FirebaseUiAuthService uiAuthService;

  /// The api (the dart functions of the flavor, or the in process server).
  final A apiService;

  /// The in memory backend of the demo, null otherwise.
  final B? memoryBackend;

  /// The firebase services an app runs against, reached by [mode] (see
  /// the class documentation for each field).
  FestenaoAppFirebase({
    required this.context,
    required this.mode,
    required this.uiAuthService,
    required this.apiService,
    this.memoryBackend,
  });

  /// True for the in memory demo.
  bool get isDemo => mode == FestenaoFirebaseMode.memory;

  @override
  String toString() =>
      'FestenaoAppFirebase($mode, ${context.firebaseApp.options.projectId})';
}

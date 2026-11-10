import 'package:festenao_google_auth/google_auth.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:tekartik_firebase_flutter_ui_auth/src/firebase_ui_auth_service_flutter.dart'
    show firebaseUiAuthEnsureProviders;

/// The error firebase_ui_auth throws when it configures its providers before
/// any firebase app exists.
final _isFirebaseUiAuthConfigureError = isA<Exception>().having(
  (e) => '$e',
  'message',
  contains('Firebase.initializeApp()'),
);

void main() {
  // No firebase app is initialized here: anything that configures the
  // firebase_ui_auth providers throws.
  group('initFestenaoGoogleAuth', () {
    test('configures nothing at startup', () async {
      // Lazy, as FirebaseUiAuthServiceFlutter.configureProviders: Google
      // Sign-In must not start before the user opens an auth screen.
      await initFestenaoGoogleAuth(clientId: 'test.apps.googleusercontent.com');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('the first auth screen configures the providers', () async {
      await initFestenaoGoogleAuth(clientId: 'test.apps.googleusercontent.com');
      // What every auth screen calls before it builds.
      expect(
        () => firebaseUiAuthEnsureProviders(),
        throwsA(_isFirebaseUiAuthConfigureError),
      );
      // Once only.
      firebaseUiAuthEnsureProviders();
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}

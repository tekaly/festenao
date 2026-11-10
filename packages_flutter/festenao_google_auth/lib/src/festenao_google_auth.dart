import 'package:tekartik_firebase_flutter_ui_auth/ui_auth.dart';

/// Sets the Firebase UI auth providers: email/password and Google with
/// [clientId], for the default firebase app.
///
/// Call it once at startup, before any auth screen is shown. Lazy, as
/// [FirebaseUiAuthServiceFlutter.configureProviders] (which it calls): the
/// providers are configured by the first auth screen, so Google Sign-In does
/// not start (nor set its `g_state` cookie on the web) before the user opens
/// one, and the firebase app may be initialized after this call.
///
/// [clientId] is the Google OAuth client id of the running platform: the web
/// client id on the web, the iOS client id on iOS and macOS (Android ignores
/// it and reads `google-services.json`).
///
/// It replaces the providers of an earlier
/// [FirebaseUiAuthServiceFlutter.configureProviders] call not yet applied
/// (the last call before the first auth screen wins).
Future<void> initFestenaoGoogleAuth({required String clientId}) async {
  firebaseUiAuthServiceFlutter.configureProviders(googleAuthClientId: clientId);
}

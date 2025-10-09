import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';

/// Initializes the Firebase UI authentication providers for email and Google.
///
/// This function should be called once at the application startup.
///
/// It configures [FirebaseUIAuth] with an [EmailAuthProvider] and a
/// [GoogleProvider] with the specified [clientId].
Future<void> initFestenaoGoogleAuth({required String clientId}) async {
  FirebaseUIAuth.configureProviders([
    EmailAuthProvider(),
    GoogleProvider(clientId: clientId),
  ]);
}

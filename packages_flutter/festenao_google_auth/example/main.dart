import 'package:festenao_google_auth/google_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_firebase_auth_flutter/auth_flutter.dart';
import 'package:tekartik_firebase_flutter/firebase_flutter.dart';

/// The Google OAuth client id of the running platform (here the web one).
const googleClientId = '000000000000-xxxxxxxx.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The native configuration of the project (flutterfire configure).
  var app = await firebaseFlutter.initializeAppAsync();
  var auth = firebaseAuthServiceFlutter.auth(app);
  // Nothing starts here: the first auth screen sets the providers.
  await initFestenaoGoogleAuth(clientId: googleClientId);
  runApp(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  // Welcome, sign in / create account, account details.
                  builder: (_) => authFlutterScreen(firebaseAuth: auth),
                ),
              ),
              child: const Text('Account'),
            ),
          ),
        ),
      ),
    ),
  );
}

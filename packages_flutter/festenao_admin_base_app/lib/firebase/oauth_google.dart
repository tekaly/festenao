import 'package:firebase_ui_auth/firebase_ui_auth.dart' as native;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart'
    as native;

Future<void> initAuthGoogle() async {
  // notelio
  var clientId =
      '524496609080-nrhtlm2d5dk0or7eg2k81hd17phbjsk3.apps.googleusercontent.com';

  native.FirebaseUIAuth.configureProviders([
    native.EmailAuthProvider(),
    native.GoogleProvider(clientId: clientId),
  ]);
}

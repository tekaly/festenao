import 'package:flutter/widgets.dart';
import 'package:tekartik_firebase_auth_flutter/auth_flutter.dart';
import 'package:tekartik_firebase_firestore_flutter/firestore_flutter.dart';
import 'package:tekartik_firebase_flutter/firebase_flutter.dart';
import 'package:tekartik_firebase_flutter_ui_auth/ui_auth.dart';
import 'package:tekartik_firebase_storage_flutter/storage_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The native configuration of the project (flutterfire configure).
  var app = await firebaseFlutter.initializeAppAsync();
  // The products, on the platform neutral tekartik interfaces.
  var firestore = firestoreServiceFlutter.firestore(app);
  var storage = storageServiceFlutter.storage(app);
  var auth = firebaseAuthServiceFlutter.auth(app);
  // The native sign in screens: email/password (lazy, set by the first
  // auth screen, firebaseUiAuthServiceFlutter.authScreen(firebaseAuth: auth)).
  firebaseUiAuthServiceFlutter.configureProviders(firebaseAuth: auth);

  var snapshot = await firestore.doc('public/hello').get();
  runApp(
    Center(
      child: Text(
        '${app.projectId}: public/hello exists ${snapshot.exists}, '
        'bucket ${storage.bucket().name}, '
        'user ${auth.currentUser?.uid}',
        textDirection: TextDirection.ltr,
      ),
    ),
  );
}

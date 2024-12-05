import 'package:flutter/material.dart';
import 'package:tekartik_firebase_ui_auth/ui_auth.dart';

/// Firebase auth service
var useFirebaseAuth = false;

/// Firebase auth service
var globalAuthFlutterUiService = FirebaseUiAuthServiceBasic();

/// Go to auth screen
Future<void> goToAuthScreen(BuildContext context) async {
  await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => globalAuthFlutterUiService.authScreen(
          /*
                  firebaseAuth:
                  globalFirebaseContext.auth))*/
          )));
}
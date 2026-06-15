import 'package:flutter/material.dart';

import 'package:tekartik_firebase_ui_auth/ui_auth.dart' as ui;

ui.FirebaseUiAuthService? globalAuthFlutterUiServiceOrNull;
ui.FirebaseUiAuthService get globalAuthFlutterUiService =>
    globalAuthFlutterUiServiceOrNull!;
set globalAuthFlutterUiService(ui.FirebaseUiAuthService value) =>
    globalAuthFlutterUiServiceOrNull = value;

/// Firebase auth service
var useFirebaseAuth = false;

/// Go to auth screen
Future<void> goToAuthScreen(BuildContext context) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => globalAuthFlutterUiService.authScreen(
        /*
                  firebaseAuth:
                  globalFirebaseContext.auth))*/
      ),
    ),
  );
}

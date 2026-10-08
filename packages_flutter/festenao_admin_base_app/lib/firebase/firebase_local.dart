import 'package:festenao_admin_base_app/auth/auth.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:flutter/foundation.dart';
import 'package:tekartik_firebase_ui_auth/ui_auth.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_sembast.dart';

/// Local project id
const localProjectId = 'festenao-base-local';

/// Initialize festenao firebase services
///
/// Also sets the auth screens ([globalAuthFlutterUiService]) the local auth
/// works with.
Future<FirebaseContext> initFestenaoFirebaseServicesLocal({
  required DatabaseFactory sembastDatabaseFactory,
  String? projectId,
}) async {
  projectId ??= localProjectId;
  var servicesContext = initFirebaseServicesLocalSembast(
    databaseFactory: sembastDatabaseFactory,
    projectId: projectId,
    isWeb: kIsWeb,
  );
  globalAuthFlutterUiService = const FirebaseUiAuthServiceBasic();
  return await servicesContext.init();
}

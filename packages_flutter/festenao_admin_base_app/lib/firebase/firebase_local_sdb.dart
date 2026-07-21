import 'package:festenao_admin_base_app/auth/auth.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:flutter/foundation.dart';
import 'package:tekartik_firebase_ui_auth/ui_auth.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

/// Local project id
const localProjectId = 'festenao-base-local';

/// Initialize festenao firebase services
Future<FirebaseContext> initFestenaoAdminFirebaseContextLocalSdb({
  required SdbFactory sdbFactory,
  String? projectId,
}) async {
  projectId ??= localProjectId;
  var servicesContext = initFirebaseServicesLocalSdb(
    sdbFactory: sdbFactory,
    projectId: projectId,
    isWeb: kIsWeb,
  );
  globalAuthFlutterUiService = const FirebaseUiAuthServiceBasic();
  return await servicesContext.init();
}

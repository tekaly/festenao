import 'package:flutter/foundation.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

/// Local project id
const localProjectId = 'festenao-base-local';

/// Initialize festenao firebase services
Future<FirebaseContext> initFestenaoFirebaseServicesLocal({
  String? projectId,
}) async {
  projectId ??= localProjectId;
  var servicesContext = initFirebaseServicesLocalSembast(
    projectId: projectId,
    isWeb: kIsWeb,
  );
  return await servicesContext.init();
}

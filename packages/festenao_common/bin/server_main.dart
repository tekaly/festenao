// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:festenao_common/data/src/firebase_constant.dart';
import 'package:festenao_common/server/festeano_server_app.dart';
import 'package:tekartik_common_utils/env_utils.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_common/tkcms_server.dart';

Future main() async {
  // ignore: avoid_print
  print('festenao starting...');

  var ffContext = await initFirebaseServicesLocalSembast(
          projectId: festenaoPlaceholderProjectId, useHttpFunctions: true)
      .initServer();
  var appDev = FestenaoServerApp(
    context: TkCmsServerAppContext(
      firebaseContext: ffContext,
      flavorContext: FlavorContext.dev,
    ),
  );
  appDev.initFunctions();

  if (!isDebug) {
    if (kDartIsWeb) {
    } else {
      // ignore: avoid_print
      print('http://localhost:4999/ampdev/app/test');
    }
  }
  await ffContext.functions.serve();
}

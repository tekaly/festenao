// ignore_for_file: depend_on_referenced_packages
import 'dart:async';

import 'package:festenao_common/data/src/firebase_constant.dart';
import 'package:festenao_common/server/festeano_server_app.dart';
import 'package:path/path.dart';
import 'package:tekartik_app_sembast/sembast.dart';
import 'package:tekartik_common_utils/env_utils.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_common/tkcms_server.dart';

DatabaseFactory prvFestenaoCommonGetSembastDatabaseFactory(
  AppFlavorContext appFlavorContext,
) {
  return getDatabaseFactory(
    rootPath: join('.local', 'festenao_common', appFlavorContext.uniqueAppName),
  );
}

Future main() async {
  // ignore: avoid_print
  print('festenao starting...');

  var appFlavorContext = FlavorContext.dev.toAppFlavorContext(
    appId: 'festenao',
  );
  var databaseFactory = prvFestenaoCommonGetSembastDatabaseFactory(
    appFlavorContext,
  );
  var ffContext = await initFirebaseServicesLocalSembast(
    databaseFactory: databaseFactory,
    projectId: festenaoPlaceholderProjectId,
    useHttpFunctions: true,
  ).initServer();
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

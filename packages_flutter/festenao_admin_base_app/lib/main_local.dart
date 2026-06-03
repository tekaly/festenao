import 'package:festenao_admin_base_app/firebase/firebase_local.dart';
import 'package:festenao_admin_base_app/run.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_common/app/app_options.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:path/path.dart';
import 'package:tekartik_app_flutter_sembast/sembast.dart';

DatabaseFactory prvFestenaoAdminBaseGetSembastDatabaseFactory(
  AppFlavorContext appFlavorContext,
) {
  return getDatabaseFactory(
    rootPath: join(
      '.local',
      'festenao_base_app',
      appFlavorContext.uniqueAppName,
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await localFestenaoRunAdminApp();
}

Future<void> localFestenaoRunAdminApp({
  FestenaoAppOptions? options,
  AppFlavorContext? appFlavorContext,
  String? singleProjectId,
  String? packageName,
}) async {
  appFlavorContext ??= AppFlavorContext.testLocal;
  var fbContext = await initFestenaoFirebaseServicesLocal(
    sembastDatabaseFactory: prvFestenaoAdminBaseGetSembastDatabaseFactory(
      appFlavorContext,
    ),
  );
  await festenaoRunAdminApp(
    packageName: packageName,
    options: options,
    singleProjectId: singleProjectId,
    appFlavorContext: appFlavorContext,
    firebaseContext: fbContext,
  );
}

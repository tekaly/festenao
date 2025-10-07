import 'package:festenao_admin_base_app/admin_app/festenao_admin_app.dart';
import 'package:festenao_admin_base_app/firebase/firebase_compat.dart';
import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/layout/drawer.dart';
import 'package:festenao_admin_base_app/route/navigator_def.dart';
import 'package:festenao_base_app/firebase/firebase_compat.dart';
import 'package:festenao_common/data/festenao_firebase.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/data/src/festenao_db.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_sembast/sembast.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';

export 'package:festenao_admin_base_app/admin_app/festenao_admin_app.dart';

late FestenaoDb festenaoDb;

class LoginScreenOptions {
  final bool stayWhenLoggedIn;

  LoginScreenOptions({this.stayWhenLoggedIn = false});
}

class AdminApp {
  // Set by caller
  late FbContext fbContext;

  /*
  late Prefs prefs;

  // AppOptions? _options;

  // Can be set by caller
  //FestenaoAppOptions options = appOptionsDefault;
  //FestenaoImageAppOptions? imageOptions = appOptionsDefault.image.v;
  */
  Future<void> Function(BuildContext context, [LoginScreenOptions? options])?
  goToLoginScreen;
  /*
  Future<Prefs> openPrefs() async {
    var prefsFactory =
        getPrefsFactory(packageName: 'com.tekartik.festenao.admin');
    prefs = await prefsFactory.openPreferences('admin_prefs.db');
    return prefs;
  }
  */
  ImageFormat get prefsImageFormat {
    return globalFestenaoAdminApp.prefsImageFormat;
  }

  set prefsImageFormat(ImageFormat format) =>
      globalFestenaoAdminApp.prefsImageFormat = format;
}

/*
var _imageFormatMap = <ImageFormat, String>{
  ImageFormat.jpg: 'jpg',
  ImageFormat.png: 'png',
};
var _reverseImageFormatMap =
    _imageFormatMap.map((key, value) => MapEntry(value, key));
*/
final app = AdminApp();
AdminApp get gAdminApp => app;

FbContext get fbContext => app.fbContext;

Firestore get fbFirestore => app.fbContext.firestore!;

String get fbFirestoreRootPath => fbContext.firestoreRootPath!;

FirestoreService get fbFirestoreService => app.fbContext.firestoreService!;
/*
class FestenaoImageAppOptions extends CvModelBase {
  final main = CvModelField<FestenaoAppImageOptions>('main');
  final square = CvModelField<FestenaoAppImageOptions>('square');
  final thumb = CvModelField<FestenaoAppImageOptions>('thumb');

  @override
  late final fields = [main, square, thumb];
}

@override
// main, square, thumb are the default prefix.
class FestenaoAppOptions extends CvModelBase {
  final image = CvModelField<FestenaoImageAppOptions>('image');

  @override
  // TODO: implement fields
  List<CvField> get fields => [image];
}

var appOptionsDefault = FestenaoAppOptions()
  ..image.v = (FestenaoImageAppOptions()
    ..main.v = (FestenaoAppImageOptions()..width.v = 800)
    ..square.v = (FestenaoAppImageOptions()..width.v = 320)
    ..thumb.v = (FestenaoAppImageOptions()..width.v = 48));
*/
const packageNameDefault = 'com.tekartik.festenao.adminapp';
String? packageName;

void _setFbContext(FbContext context) {
  app.fbContext = context;
}

/// If only package name is specified, it is a global application
DatabaseFactory initDatabaseFactory() {
  return getDatabaseFactory(packageName: packageName);
}

Future<void> initAndRunFestenaoAdminApp({
  FbContext? fbContext,
  String? packageName,
  VoidCallback? parentAction,
}) async {
  await initAndRunFestenaoAdminAppCompat(
    fbContext: fbContext,
    packageName: packageName,
    parentAction: parentAction,
  );
}

/// Helper v1 see
/// Used by admin internally
/// parent allow going back to the application
Future<void> initAndRunFestenaoAdminAppCompat({
  FbContext? fbContext,
  String? packageName,
  VoidCallback? parentAction,
}) async {
  /// Set the global package name
  packageName = packageName ?? packageNameDefault;

  if (fbContext != null) {
    _setFbContext(fbContext);
    // Set for storage no-auth read access
    appDataContext = AppDataContext(
      projectId: fbContext.projectId!,
      rootPath: fbContext.storageRootPath!,
    );
  }
  // devPrint(await fs.getApplicationDocumentsDirectory(packageName: packageName));
  initFestenaoFsBuilders();
  WidgetsFlutterBinding.ensureInitialized();

  var databaseFactory = initDatabaseFactory();
  festenaoDb = FestenaoDb(databaseFactory);
  // Trigger opening
  festenaoDb.database.unawait();

  /// Config compat
  await initConfigV2FromV1(syncedDb: festenaoDb);

  /// Open prefs on start
  await globalFestenaoAdminApp.openPrefs();
  /*
  if (devWarning(true)) {
    print('#Before');
    print((await artistStore.query().getRecords(await festenaoDb.database))
        .map((e) => e.id));
    print(await sync());
    print('#After');
    print((await artistStore.query().getRecords(await festenaoDb.database))
        .map((e) => e.id));
    return;
  }*/
  adminGoToAppParentAction = parentAction;
  runApp(const FestenaroAdminApp());
}

final contentNavigatorDef = ContentNavigatorDef(
  defs: [...List.from(festenaoAdminAppPages)],
);

class FestenaroAdminApp extends StatelessWidget {
  const FestenaroAdminApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // festenaoUseContentPathNavigation = devWarning(true); // devWarning(false);
    return ContentNavigator(
      def: contentNavigatorDef,
      child: Builder(
        builder: (context) {
          var cn = ContentNavigator.of(context);
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Festenao Admin',
            routerDelegate: cn.routerDelegate,
            routeInformationParser: cn.routeInformationParser,

            supportedLocales: festenaoAdminAppSupportedLocales,
            //locale: Locale(getCurrentLocale()),
            localizationsDelegates: const [
              ...festenaoAdminAppAllLocalizationsDelegates,
            ],

            theme: ThemeData(
              // This is the theme of your application.
              //
              // Try running your application with "flutter run". You'll see the
              // application has a blue toolbar. Then, without quitting the app, try
              // changing the primarySwatch below to Colors.green and then invoke
              // "hot reload" (press "r" in the console where you ran "flutter run",
              // or simply save your changes to "hot reload" in a Flutter IDE).
              // Notice that the counter didn't reset back to zero; the application
              // is not restarted.
              primarySwatch: Colors.blue,
            ),
            //routeInformationParser: cn.,
            //home: AdminAppHomePage(
            //        title: 'Festenao edit data',
            //    ),
          );
        },
      ),
    );
  }
}

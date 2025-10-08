import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/route/navigator_def.dart';
// ignore: unused_import
import 'package:festenao_admin_base_app/route/route_navigation.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/sembast/sembast.dart';
import 'package:festenao_common/app/src/app_init_options.dart';
import 'package:festenao_common/data/src/model/db_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_common_utils/common_utils_import.dart';
import 'package:tekartik_app_flutter_sembast/sembast.dart';
import 'package:tekartik_app_navigator_flutter/route_aware.dart';
import 'package:tekartik_app_prefs/app_prefs.dart';
import 'package:tkcms_admin_app/app.dart';
import 'package:tkcms_admin_app/auth/auth.dart';
import 'package:tkcms_admin_app/firebase/database_service.dart';
import 'package:tkcms_admin_app/screen/project_info.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_firestore_v2.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_common/tkcms_sembast.dart';
import 'package:tkcms_user_app/theme/theme1.dart';

import 'admin_app/festenao_admin_app.dart';
import 'firebase/firebase_local.dart';
import 'l10n/app_intl.dart';
import 'prefs/local_prefs.dart';
import 'sembast/projects_db_bloc.dart';

/// Prefer festenaoRunAdminApp
Future<void> festenaoRunApp({
  ContentNavigatorDef? contentNavigatorDef,
  AppFlavorContext? appFlavorContext,
  String? packageName,
  String? singleProjectId,
  FirebaseContext? firebaseContext,
}) => festenaoRunAdminApp(
  appFlavorContext: appFlavorContext,
  contentNavigatorDef: contentNavigatorDef,
  packageName: packageName,
  singleProjectId: singleProjectId,
  firebaseContext: firebaseContext,
);

/// Compat mode mainly
Future<void> festenaoRunAdminAppSingleProject({
  ContentNavigatorDef? contentNavigatorDef,
  AppFlavorContext? appFlavorContext,
  String? packageName,
  String? singleProjectId,
  FirebaseContext? firebaseContext,
  required FestenaoAppFirebaseContext appFirebaseContext,
}) async {
  await festenaoRunAdminApp(
    contentNavigatorDef: contentNavigatorDef,
    appFlavorContext: appFlavorContext,
    packageName: packageName,
    singleProjectId: singleProjectId,
    firebaseContext: firebaseContext,
    appFirebaseContext: appFirebaseContext,
  );
}

Future<void> festenaoRunAdminApp({
  ContentNavigatorDef? contentNavigatorDef,
  AppFlavorContext? appFlavorContext,
  String? packageName,
  FestenaoAppInitOptions? initOptions,
  String? singleProjectId,
  FestenaoAppFirebaseContext? appFirebaseContext,
  FirebaseContext? firebaseContext,
}) async {
  if (kDebugMode) {
    gDebugLogFirestore = true;
  }
  // festenaoUseContentPathNavigation = devWarning(true);
  WidgetsFlutterBinding.ensureInitialized();
  webSplashReady();
  packageName ??= 'festenao.admin_base_app';

  await initFestenaoLocalSembastFactory();

  var prefsFactory = getPrefsFactory(packageName: packageName);
  var prefs = await prefsFactory.openPreferences('${packageName}_prefs.db');
  globalPrefs = prefs;

  var appId = prefs.currentAppId;
  appFlavorContext ??= AppFlavorContext.testLocal;
  if (appId != null) {
    appFlavorContext = appFlavorContext.copyWithAppId(appId);
  }

  //initFirebaseSim(projectId: 'festenao', packageName: packageName);
  firebaseContext ??= await initFestenaoFirebaseServicesLocal();

  globalTkCmsAdminAppFirebaseContext = firebaseContext;
  var fsDatabase = FestenaoFirestoreDatabase(
    firebaseContext: firebaseContext,
    flavorContext: appFlavorContext,
  );
  if (kDebugMode) {
    print('appFlavorContext: $appFlavorContext');
  }
  gFsDatabaseService = fsDatabase;
  globalTkCmsAdminAppFlavorContext = appFlavorContext;

  globalFestenaoFirestoreDatabaseOrNull ??= fsDatabase;
  gAuthBloc = TkCmsAuthBloc.local(db: fsDatabase, prefs: prefs);

  /// Global prefs (last entered values)
  var app = globalTkCmsAdminAppFlavorContext.uniqueAppName;
  await globalFestenaoAdminApp.openPrefs();

  globalPackageName = packageName;
  if (appFirebaseContext != null) {
    if (globalProjectsDbBlocOrNull == null) {
      var dbFactory = getDatabaseFactory(packageName: packageName);
      var festenaoDb = FestenaoDb(dbFactory);
      // Trigger opening
      try {
        festenaoDb.initialSynchronizationDone().unawait();
        festenaoDb.database.unawait();
      } catch (e) {
        // Ignore
        if (kDebugMode) {
          print('Error opening db $e');
        }
      }
      globalProjectsDbBlocOrNull ??= SingleProjectDbBloc(syncedDb: festenaoDb);
    }
  } else {
    globalProjectsDbBlocOrNull ??= (singleProjectId == null)
        ? MultiProjectsDbBloc(app: app)
        : EnforcedSingleProjectDbBloc(app: app, projectId: singleProjectId);
  }
  initFestenaoFsBuilders();

  // TODO remove
  fsProjectSyncedDb = SyncedEntitiesDb<TkCmsFsProject>(
    entityAccess: tkCmsFsProjectAccess,
    options: SyncedEntitiesOptions(
      sembastDatabaseContext: SembastDatabaseContext(
        factory: globalSembastDatabaseFactory,
        path: '.',
      ),
    ),
  );

  initFestenaoDbBuilders();
  sleep(300).then((_) {
    webSplashHide();
  }).unawait();
  runApp(FestenaoAdminApp(contentNavigatorDef: contentNavigatorDef));
}

/// Festenao admin app
class FestenaoAdminApp extends StatelessWidget {
  final ContentNavigatorDef? contentNavigatorDef;

  /// Festenao admin app
  const FestenaoAdminApp({super.key, this.contentNavigatorDef});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ContentNavigator(
      def: contentNavigatorDef ?? festenaoAdminAppContentNavigatorDef,
      observers: [routeAwareObserver],
      child: Builder(
        builder: (context) {
          var cn = ContentNavigator.of(context);
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'Festenao admin',
            theme: themeData1(),
            //navigatorObservers: [cn.routeObserver],
            routerDelegate: cn.routerDelegate,
            routeInformationParser: cn.routeInformationParser,
            supportedLocales: festenaoAdminAppSupportedLocales,
            //locale: Locale(getCurrentLocale()),
            localizationsDelegates: const [
              ...festenaoAdminAppAllLocalizationsDelegates,
            ],
          );
        },
      ),
    );
  }
}

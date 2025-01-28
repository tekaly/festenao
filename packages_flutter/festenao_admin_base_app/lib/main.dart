import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/l10n/app_localizations.dart';
import 'package:festenao_admin_base_app/route/navigator_def.dart';
import 'package:festenao_admin_base_app/sembast/sembast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tekartik_app_flutter_common_utils/common_utils_import.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';
import 'package:tekartik_app_navigator_flutter/route_aware.dart';
import 'package:tekartik_app_prefs/app_prefs.dart';
import 'package:tekartik_firebase_ui_auth/ui_auth.dart';
import 'package:tkcms_admin_app/auth/auth.dart';
import 'package:tkcms_admin_app/l10n/app_localizations.dart' as tkcms;
import 'package:tkcms_admin_app/screen/login_screen.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_user_app/theme/theme1.dart';

import 'admin_app/festenao_admin_app.dart';
import 'firebase/firebase_local.dart';

Future<void> main() async {
  var packageName = 'festenao.admin_base_app';
  await initLocalSembastFactory();
  var prefsFactory = getPrefsFactory(packageName: packageName);
  var prefs = await prefsFactory.openPreferences('${packageName}_prefs.db');
  var context = await initFestenaoFirebaseServicesLocal();
  //initFirebaseSim(projectId: 'festenao', packageName: packageName);
  globalAdminAppFirebaseContext = context;
  var fsDatabase = FestenaoFirestoreDatabase(
      firebaseContext: context, flavorContext: AppFlavorContext.testLocal);
  globalEntityDatabase = fsDatabase;
  gAuthBloc = TkCmsAuthBloc.local(db: fsDatabase, prefs: prefs);
  globalPackageName = 'tekaly.festenao';
  globalFestenaoAppFirebaseContext = FestenaoAppFirebaseContext(
      storageRootPath: 'festenao', firestoreRootPath: 'festenao');
  gDebugUsername = 'admin';
  gDebugPassword = '__admin__'; // irrelevant

  //await initFestenaoFirebaseServicesLocal();
  runApp(const FestenaoAdminApp());
}

/// Festenao admin app
class FestenaoAdminApp extends StatelessWidget {
  /// Festenao admin app
  const FestenaoAdminApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ContentNavigator(
      def: contentNavigatorDef,
      observers: [routeAwareObserver],
      child: Builder(builder: (context) {
        var cn = ContentNavigator.of(context);
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Festenao admin',
          theme: themeData1(),
          //navigatorObservers: [cn.routeObserver],
          routerDelegate: cn.routerDelegate,
          routeInformationParser: cn.routeInformationParser,
          supportedLocales: AppLocalizations.supportedLocales,
          //locale: Locale(getCurrentLocale()),
          localizationsDelegates: const [
            FirebaseUiAuthServiceBasicLocalizations.delegate,
            AppLocalizations.delegate,
            tkcms.AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      }),
    );
  }
}

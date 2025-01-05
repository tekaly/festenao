import 'package:festenao_admin_base_app/admin_app/menu.dart';
import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/sembast/sembast.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_common_utils/common_utils_import.dart';
import 'package:tekartik_app_prefs/app_prefs.dart';
import 'package:tkcms_admin_app/auth/auth.dart';
import 'package:tkcms_admin_app/screen/login_screen.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

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
  globalFestenaoFirebaseContext = FestenaoFirebaseContext(
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
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: festenaoAdminDebugScreen,
    );
  }
}

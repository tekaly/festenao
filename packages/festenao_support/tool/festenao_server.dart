// ignore_for_file: avoid_print, unnecessary_import, depend_on_referenced_packages

import 'package:festenao_common/festenao_firebase.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/firebase/firebase_sim.dart';
import 'package:festenao_common/firebase/firebase_sim_server.dart';
import 'package:festenao_common/test/festenao_test_server_test.dart';
import 'package:festenao_support/festenao_support.dart';
import 'package:tekartik_firebase_auth_sembast/auth_sembast.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_firebase_functions_io/firebase_functions_io.dart';
import 'package:tekartik_firebase_functions_test/firebase_functions_setup.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:tekartik_firebase_sim/firebase_sim_server.dart';
import 'package:tekartik_firebase_storage_fs/storage_fs_io.dart';

var port = firebaseSimDefaultPort;
Future<void> main(List<String> args) async {
  //debugFirebaseSimServer = devTrue;
  //debugFirebaseSimClient = devTrue;
  void initFunctions({
    required FirebaseServicesContext firebaseServicesContext,
    required FirebaseApp firebaseApp,
  }) {
    print('initFunctions');
    var serverApp = FestenaoServerAppTest(
      context: TkCmsServerAppContext(
        flavorContext: FlavorContext.dev,
        firebaseContext: firebaseServicesContext.initSync(),
      ),
    );
    serverApp.initFunctions();
  }

  var festenaoSimServer = await initFestenaoSimServer(
    initFunction: initFunctions,
  );
  print('url ${festenaoSimServer.uri}');
  var client = getFirebaseSim(uri: festenaoSimServer.uri);
  await client.initializeAppAsync();
}

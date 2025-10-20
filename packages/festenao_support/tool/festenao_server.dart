// ignore_for_file: avoid_print, unnecessary_import, depend_on_referenced_packages

import 'package:festenao_common/firebase/firebase_sim_server.dart';
import 'package:tekartik_firebase_auth_sembast/auth_sembast.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_firebase_functions_io/firebase_functions_io.dart';
import 'package:tekartik_firebase_functions_test/firebase_functions_setup.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:tekartik_firebase_sim/firebase_sim_server.dart';
import 'package:tekartik_firebase_storage_fs/storage_fs_io.dart';

var port = firebaseSimDefaultPort;
Future<void> main(List<String> args) async {
  void initFunctions({
    required FirebaseFunctionsService functionsService,
    required FirebaseApp firebaseApp,
  }) {
    var functions = functionsService.functions(firebaseApp);
    initTestFunctions(firebaseFunctions: functions);
  }

  var festenaSimServer = await initFestenaoSimServer(
    initFunction: initFunctions,
  );
  print('url ${festenaSimServer.uri}');
}

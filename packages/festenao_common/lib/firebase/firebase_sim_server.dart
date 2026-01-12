// ignore_for_file: avoid_print
import 'package:festenao_common/festenao_firebase.dart';
import 'package:path/path.dart';
import 'package:tekartik_app_sembast/sembast.dart';
import 'package:tekartik_firebase_auth_sembast/auth_sembast.dart';
import 'package:tekartik_firebase_auth_sim/auth_sim_server.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:tekartik_firebase_firestore_sim/firestore_sim_server.dart';
import 'package:tekartik_firebase_functions_call_sim/functions_call_sim_server.dart';
import 'package:tekartik_firebase_functions_io/firebase_functions_io.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:tekartik_firebase_sim/firebase_sim_server.dart';
import 'package:tekartik_firebase_storage_fs/storage_fs_io.dart';
import 'package:tekartik_firebase_storage_sim/storage_sim_server.dart';

export 'package:tekartik_firebase_auth_sembast/auth_sembast.dart';
export 'package:tekartik_firebase_auth_sim/auth_sim_server.dart';
export 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
export 'package:tekartik_firebase_firestore_sim/firestore_sim_server.dart';
export 'package:tekartik_firebase_functions_call_sim/functions_call_sim_server.dart';
export 'package:tekartik_firebase_functions_io/firebase_functions_io.dart';
export 'package:tekartik_firebase_local/firebase_local.dart';
export 'package:tekartik_firebase_sim/firebase_sim_server.dart';

/// Default port for Firebase sim server.
var port = firebaseSimDefaultPort;

/// Festenao simulation server.
class FestenaoSimServer {
  /// The firebase sim server.
  final FirebaseSimServer firebaseSimServer;

  /// The firebase services context.
  final FirebaseServicesContext firebaseServicesContext;

  /// Constructor for [FestenaoSimServer].
  FestenaoSimServer({
    required this.firebaseSimServer,
    required this.firebaseServicesContext,
  });

  /// The URI of the server.
  Uri get uri => firebaseSimServer.uri;
}

/// Global init function
Future<FestenaoSimServer> initFestenaoSimServer({
  void Function({
    required FirebaseServicesContext firebaseServicesContext,
    required FirebaseApp firebaseApp,
  })?
  initFunction,
}) async {
  var databaseFactory = getDatabaseFactory();
  var firebaseLocal = FirebaseLocal(
    localPath: join('.local', 'firebase_festenao'),
  );

  var functionsService = firebaseFunctionsServiceIo;
  var storageService = storageServiceIo;
  var firestoreService = FirestoreServiceSembast(databaseFactory);
  var authService = FirebaseAuthServiceSembast(
    databaseFactory: databaseFactory,
  );
  var firebaseServicesContext = FirebaseServicesContext(
    firebase: firebaseLocal,
    storageService: storageService,
    firestoreService: firestoreService,
    authService: authService,
    functionsService: functionsService,
  );
  void localInitFunction({required FirebaseApp firebaseApp}) {
    initFunction?.call(
      firebaseServicesContext: firebaseServicesContext,
      firebaseApp: firebaseApp,
    );
  }

  var firebaseSimServer = await firebaseSimServe(
    firebaseLocal,
    webSocketChannelServerFactory: webSocketChannelServerFactoryIo,
    port: port,
    plugins: [
      FirebaseAuthSimPlugin(
        firebaseAuthSimServerService: FirebaseAuthSimServerService(),
        firebaseAuthService: authService,
      ),
      FirestoreSimPlugin(firestoreService: firestoreService),

      FirebaseFunctionsCallSimPlugin(
        firebaseFunctionsService: functionsService,
        options: FirebaseFunctionsCallSimPluginOptions(
          initFunction: localInitFunction,
        ),
      ),
      StorageSimPlugin(storageService: storageService),
    ],
  );
  print('sim_server_url ${firebaseSimServer.url}');
  return FestenaoSimServer(
    firebaseSimServer: firebaseSimServer,
    firebaseServicesContext: firebaseServicesContext,
  );
}

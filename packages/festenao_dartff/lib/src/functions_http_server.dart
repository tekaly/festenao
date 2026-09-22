import 'package:tekartik_firebase_functions_admin_sdk_http/functions_admin_sdk_http.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:tekartik_http_io/http_server_io.dart';

/// The port the standalone festenao function servers listen on by default.
const festenaoFunctionsHttpServerPort = 8040;

/// Serves the dart http functions [declare] registers on a standalone http
/// server listening on [port]: the admin sdk http runner, the same handlers
/// as the deployed `functions/bin/server.dart`, reached at
/// `http://localhost:<port>/<function>/...`.
///
/// [firebaseApp] defaults to an in memory app, enough for functions that
/// need no firebase service (a cms site); [httpServerFactory] to io (pass
/// `httpFactoryMemory.server` in a test). Returns the functions, whose
/// `httpServer` is the server to close.
Future<FirebaseFunctionsAdminSdkHttp> serveFestenaoFunctionsHttp({
  required TekartikFirebaseFunctionsAdminSdkHttpRunner declare,
  FirebaseApp? firebaseApp,
  int port = festenaoFunctionsHttpServerPort,
  HttpServerFactory? httpServerFactory,
}) async {
  firebaseApp ??= newFirebaseMemory().initializeApp(
    options: FirebaseAppOptions(projectId: 'festenao-local'),
  );
  late FirebaseFunctionsAdminSdkHttp functions;
  await FirebaseFunctionsServiceAdminSdkHttp(
    httpServerFactory: httpServerFactory ?? httpServerFactoryIo,
    port: port,
  ).fireUp(firebaseApp, (firebaseFunctions) async {
    functions = firebaseFunctions;
    await declare(firebaseFunctions);
  });
  return functions;
}

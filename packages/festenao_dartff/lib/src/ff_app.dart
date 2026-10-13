import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/server/festeano_server_firestore_handler.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Festenao server app for the Dart (admin sdk) cloud functions.
///
/// It has no raw firestore access (the doc api, get/set/delete any document
/// with the admin rights) unless [firestoreDocApi] is set, which only the
/// Firebase emulator does (`functions/bin/server.dart`), for the test setups.
class FfApp extends FestenaoProjectsServerApp {
  /// True to serve the raw firestore doc api, never on a deployed function.
  final bool firestoreDocApi;

  /// Creates a new [FfApp] with the given [app] and [context].
  FfApp({required super.context, super.app, this.firestoreDocApi = false}) {
    initFestenaoFsEntityApiBuilders<TkCmsFsApp>();
  }

  /// App (top entity) handler.
  late final appHandler = FestenaoEntityHandler(
    app: this,
    entityAccess: fsDatabase.appDb,
  );

  /// Firestore doc handler, served only when [firestoreDocApi] is set.
  late final firestoreHandler = FestenaoFirestoreHandler(
    options: FestenaoFirestoreHandlerOptions(firestore: fsDatabase.firestore),
  );

  @override
  List<FestenaoApiHandler> get apiHandlers => [
    appHandler,
    if (firestoreDocApi) firestoreHandler,
    ...super.apiHandlers,
  ];
}

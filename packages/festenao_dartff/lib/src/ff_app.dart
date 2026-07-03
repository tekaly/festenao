import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/server/festeano_server_firestore_handler.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Festenao server app for the Dart (admin sdk) cloud functions.
class FfApp extends FestenaoServerApp {
  /// Creates a new [FfApp] with the given [app] and [context].
  FfApp({required super.context, super.app}) {
    initFestenaoFsEntityApiBuilders<FsProject>();
    initFestenaoFsEntityApiBuilders<TkCmsFsApp>();
  }

  /// Firestore database.
  late var fsDatabase = FestenaoFirestoreDatabase(
    firebaseContext: super.firebaseContext,
    flavorContext: appFlavorContext,
  );

  /// Project handler.
  late final projectHandler = FestenaoEntityHandler(
    app: this,
    entityAccess: fsDatabase.projectDb,
  );

  /// App (top entity) handler.
  late final appHandler = FestenaoEntityHandler(
    app: this,
    entityAccess: fsDatabase.appDb,
  );

  /// Firestore doc handler.
  late final firestoreHandler = FestenaoFirestoreHandler(
    options: FestenaoFirestoreHandlerOptions(firestore: fsDatabase.firestore),
  );

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    var command = apiRequest.apiCommand;
    if (FestenaoEntityHandler.isEntityCommand(
      projectCollectionInfo.id,
      command,
    )) {
      var result = await projectHandler.onCommandOrNull(apiRequest);
      if (result != null) {
        return result;
      }
    }
    if (FestenaoEntityHandler.isEntityCommand(
      tkCmsFsAppCollectionInfo.id,
      command,
    )) {
      var result = await appHandler.onCommandOrNull(apiRequest);
      if (result != null) {
        return result;
      }
    }
    var result = await firestoreHandler.onCommandOrNull(apiRequest);
    if (result != null) {
      return result;
    }
    return super.onCommand(apiRequest);
  }
}

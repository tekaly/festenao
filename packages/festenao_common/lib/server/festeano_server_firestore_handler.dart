import 'package:festenao_common/data/firestore_doc.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_firebase_firestore/utils/json_utils.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// Options for the Firestore doc handler.
class FestenaoFirestoreHandlerOptions {
  /// Firestore instance to read/write from.
  final Firestore firestore;

  /// Creates a new [FestenaoFirestoreHandlerOptions] with the given [firestore].
  const FestenaoFirestoreHandlerOptions({required this.firestore});
}

/// Handler for raw Firestore document get/set/delete commands.
class FestenaoFirestoreHandler {
  /// Options for the handler.
  final FestenaoFirestoreHandlerOptions options;

  Firestore get _firestore => options.firestore;

  /// Creates a new [FestenaoFirestoreHandler] with the given [options].
  FestenaoFirestoreHandler({required this.options}) {
    initFirestoreDocApiBuilders();
  }

  /// Handles the command if it's a firestore doc command, otherwise returns null.
  Future<ApiResult?> onCommandOrNull(ApiRequest apiRequest) async {
    var command = apiRequest.command.v!;
    switch (command) {
      case FirestoreDocApiService.getCommand:
        return await onGetCommand(apiRequest);
      case FirestoreDocApiService.setCommand:
        return await onSetCommand(apiRequest);
      case FirestoreDocApiService.deleteCommand:
        return await onDeleteCommand(apiRequest);
    }

    return null;
  }

  /// Handles the get document command.
  Future<FirestoreDocGetResult> onGetCommand(ApiRequest apiRequest) async {
    var query = apiRequest.query<FirestoreDocGetQuery>();
    var snapshot = await _firestore.doc(query.path.v!).get();
    return FirestoreDocGetResult()
      ..exists.v = snapshot.exists
      ..data.v = snapshotDataToJsonMap(snapshot);
  }

  /// Handles the set document command.
  Future<FirestoreDocSetResult> onSetCommand(ApiRequest apiRequest) async {
    var query = apiRequest.query<FirestoreDocSetQuery>();
    var data = documentDataMapFromJsonMap(_firestore, asModel(query.data.v!));
    await _firestore.doc(query.path.v!).set(data);
    return FirestoreDocSetResult();
  }

  /// Handles the delete document command.
  Future<FirestoreDocDeleteResult> onDeleteCommand(
    ApiRequest apiRequest,
  ) async {
    var query = apiRequest.query<FirestoreDocDeleteQuery>();
    await _firestore.doc(query.path.v!).delete();
    return FirestoreDocDeleteResult();
  }
}

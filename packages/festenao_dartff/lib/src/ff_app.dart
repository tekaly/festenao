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
  ///
  /// It also lets any signed in user create an app (top) entity, the way the
  /// emulator tests make their first app admin (see [appHandler]).
  final bool firestoreDocApi;

  /// Creates a new [FfApp] with the given [app] and [context].
  FfApp({required super.context, super.app, this.firestoreDocApi = false}) {
    initFestenaoFsEntityApiBuilders<TkCmsFsApp>();
  }

  /// App (top entity) handler.
  ///
  /// The creator of an app entity becomes its admin, an app admin of the
  /// servers serving that app: only an admin of this server's app creates
  /// one (`permission-denied` otherwise), the first app admin is set with
  /// the admin rights (or, with [firestoreDocApi], by any signed in user).
  late final FestenaoEntityHandler<TkCmsFsApp> appHandler = _FfAppEntityHandler(
    app: this,
    entityAccess: fsDatabase.appDb,
    anyCreator: firestoreDocApi,
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

/// The app entity handler of [FfApp]: an app entity is created by an app
/// admin only (the entity of an app whose document does not exist yet, the
/// usual case, made any signed in user an app admin of it).
class _FfAppEntityHandler extends FestenaoEntityHandler<TkCmsFsApp> {
  final FfApp _app;

  /// True to let any signed in user create one (emulator test setups).
  final bool anyCreator;

  _FfAppEntityHandler({
    required FfApp app,
    required super.entityAccess,
    required this.anyCreator,
  }) : _app = app,
       super(app: app);

  @override
  Future<FsCmsEntityCreateApiResult> onCreateCommand(
    ApiRequest apiRequest,
  ) async {
    var userId = apiRequest.userId.v;
    // Signed out: the create refuses it (unauthenticated).
    if (!anyCreator && userId != null && !await _app.isAppAdmin(userId)) {
      throw (ApiError()
            ..code.v = HttpsErrorCode.permissionDenied
            ..message.v = 'Only an app admin creates an app'
            ..noRetry.v = true)
          .exception();
    }
    return await super.onCreateCommand(apiRequest);
  }
}

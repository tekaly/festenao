import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/festenao_quizz.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:tkcms_common/tkcms_server.dart';

import 'festeano_server_app.dart';
import 'festeano_server_entity_handler.dart';
import 'festenao_email_invite_mailer.dart';
import 'festenao_user_plan_handler.dart';

/// Festenao server app with the projects: the project entity commands and
/// the quizz commands of the projects, the app a deployed function runs.
///
/// It has no raw firestore access (get/set/delete any document): the test
/// app adds it (`FestenaoServerAppTest`), never a deployed function.
class FestenaoProjectsServerApp extends FestenaoServerApp {
  /// Creates the app.
  FestenaoProjectsServerApp({required super.context, super.app}) {
    initFestenaoFsEntityApiBuilders<FsProject>();
  }

  /// Firestore database.
  late var fsDatabase = FestenaoFirestoreDatabase(
    firebaseContext: firebaseContext,
    flavorContext: appFlavorContext,
  );

  /// The condition added to making a project public, none by default: a test
  /// sets it to exercise [FestenaoEntityHandlerOptions.setPublicCheck].
  FestenaoEntitySetPublicCheck? projectSetPublicCheck;

  /// The mailer of the project email invites, none until its `mailer` is set
  /// (a test, or the app at start: the invite mails then go).
  final projectEmailInviteMailer = FestenaoEmailInviteMailerDelegate();

  /// The users' plans of the app (the create limits set by the app admins,
  /// the blocked users), none by default: once set at start, its commands
  /// are served and the commands of a blocked user refused.
  FestenaoUserPlanHandler? userPlanHandler;

  /// Project handler.
  late final projectHandler = FestenaoEntityHandler(
    app: this,
    entityAccess: fsDatabase.projectDb,
    options: FestenaoEntityHandlerOptions(
      setPublicCheck: ({required userId, required entityId}) async =>
          await projectSetPublicCheck?.call(
            userId: userId,
            entityId: entityId,
          ) ??
          true,
      emailInviteMailer: projectEmailInviteMailer,
    ),
  );

  /// The project handlers added by [addAppProjectHandler], tried before
  /// [projectHandler].
  final _appProjectHandlers = <FestenaoEntityHandler<FsProject>>[];

  /// Serves the projects of [app] (`app/<app>/project`, its own app admins)
  /// for the requests naming it, with [options] (a create limit, see
  /// [FestenaoEntityHandlerOptions.createLimit]): at start. [app] may be the
  /// server's own, its handler then replacing [projectHandler].
  FestenaoEntityHandler<FsProject> addAppProjectHandler(
    String app, {
    FestenaoEntityHandlerOptions options = const FestenaoEntityHandlerOptions(),
  }) {
    var handler = FestenaoEntityHandler<FsProject>(
      app: this,
      entityAccess: fsDatabase.copyWithAppId(app).projectDb,
      appId: app,
      options: options,
    );
    _appProjectHandlers.add(handler);
    return handler;
  }

  /// Quizz handler, the quizz data of a project living at
  /// `app/<app>/project/<projectId>/data/<dataId>`.
  late final quizzHandler = QuizzServerHandler(
    options: QuizzServerHandlerOptions(
      firestore: fsDatabase.firestore,
      rootDocumentResolver: festenaoQuizzRootDocumentResolver(app: app),
    ),
  );

  /// The handlers a module registers (the commands of a private module, say),
  /// tried after the project and quizz ones: add them once, at start.
  final moduleApiHandlers = <FestenaoApiHandler>[];

  /// The handlers tried in order by [onCommand], before the base commands.
  List<FestenaoApiHandler> get apiHandlers => [
    ?userPlanHandler,
    ..._appProjectHandlers,
    projectHandler,
    quizzHandler,
    ...moduleApiHandlers,
  ];

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    await userPlanHandler?.requireNotBlocked(apiRequest);
    for (var handler in apiHandlers) {
      var result = await handler.onCommandOrNull(apiRequest);
      if (result != null) {
        return result;
      }
    }
    return super.onCommand(apiRequest);
  }
}

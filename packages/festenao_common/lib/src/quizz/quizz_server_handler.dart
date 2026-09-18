import 'package:festenao_common/festenao_api.dart';

import 'import.dart';
import 'model/quizz_api_models.dart';
import 'model/quizz_fs_models.dart';
import 'model/quizz_gd_fs_models.dart';
import 'quizz_constant.dart';
import 'quizz_firestore_database.dart';

/// Locates the quizz data of a [query]: the root document of its
/// `QuizzFirestoreDatabase`, null for top level collections.
///
/// The festenao one is [festenaoQuizzRootDocumentResolver], from the api app
/// and the project id of the query.
typedef QuizzRootDocumentResolver =
    FutureOr<CvDocumentReference?> Function(
      ApiRequest apiRequest,
      ApiQuizzSendResultQuery query,
    );

/// The festenao resolver: `app/<app>/project/<projectId>/data/<dataId>`, the
/// app being [app] (or the one of the request).
QuizzRootDocumentResolver festenaoQuizzRootDocumentResolver({String? app}) =>
    (apiRequest, query) {
      var projectId = query.projectId.v;
      if (projectId == null) {
        throw ArgumentError('Missing projectId in $query');
      }
      var resolvedApp = app ?? apiRequest.app.v;
      if (resolvedApp == null) {
        throw ArgumentError('Missing app in $apiRequest');
      }
      return festenaoProjectQuizzRootDocument(
        app: resolvedApp,
        projectId: projectId,
        dataId: query.dataId.v,
      );
    };

/// Options of [QuizzServerHandler].
class QuizzServerHandlerOptions {
  /// The firestore.
  final Firestore firestore;

  /// Locates the quizz data of a query.
  final QuizzRootDocumentResolver rootDocumentResolver;

  /// Creates the options.
  QuizzServerHandlerOptions({
    required this.firestore,
    required this.rootDocumentResolver,
  });
}

/// The quizz commands of a server app: [apiCommandQuizzSendResult] saves a
/// player result (scored server side from the quiz correct answers, or from
/// the client answers for a gd quiz, where a goodie can be won).
///
/// Sending the same result twice returns the same player id.
class QuizzServerHandler implements FestenaoApiHandler {
  /// The options.
  final QuizzServerHandlerOptions options;

  /// Creates the handler.
  QuizzServerHandler({required this.options}) {
    initQuizzApiBuilders();
    initQuizzGdFsBuilders();
  }

  /// The firestore.
  Firestore get firestore => options.firestore;

  /// True if [command] is a quizz command.
  static bool isQuizzCommand(String command) => command.startsWith('quizz/');

  @override
  Future<ApiResult?> onCommandOrNull(ApiRequest apiRequest) async {
    var command = apiRequest.command.v!;
    switch (command) {
      case apiCommandQuizzSendResult:
        return await onSendResultCommand(apiRequest);
    }
    return null;
  }

  /// The database of a query.
  Future<QuizzFirestoreDatabase> getDatabase(
    ApiRequest apiRequest,
    ApiQuizzSendResultQuery query,
  ) async {
    var rootDocument = await options.rootDocumentResolver(apiRequest, query);
    return QuizzFirestoreDatabase(
      firestore: firestore,
      rootDocument: rootDocument,
    );
  }

  /// Handles [apiCommandQuizzSendResult].
  Future<ApiQuizzSendResultResult> onSendResultCommand(
    ApiRequest apiRequest,
  ) async {
    var query = apiRequest.query<ApiQuizzSendResultQuery>();
    festenaoEnsureFields(
      query,
      fields: [
        apiQuizzSendResultQueryModel.quizId,
        apiQuizzSendResultQueryModel.answers,
        apiQuizzSendResultQueryModel.validation,
        apiQuizzSendResultQueryModel.localTimestamp,
      ],
    );
    var databaseService = await getDatabase(apiRequest, query);
    var quizId = query.quizId.v!;
    var quizType = query.quizType.v;
    var now = DateTime.timestamp();
    var score = 0;
    var elapsedMs = 0;

    var gdWinning = false;
    var localTimestamp = Timestamp.parse(query.localTimestamp.v!);
    var localDeviceId = query.localDeviceId.v;

    if (now.difference(localTimestamp.toDateTime()).inMinutes.abs() > 30) {
      throw ArgumentError('Invalid localTimestamp $localTimestamp');
    }
    if (quizType == quizTypeGd) {
      festenaoEnsureFields(
        query,
        fields: [
          apiQuizzSendResultQueryModel.sessionId,
          apiQuizzSendResultQueryModel.winningCount,
          apiQuizzSendResultQueryModel.localDeviceId,
        ],
      );

      var winningCount = query.winningCount.v!;

      if (query.answers.isNotNull) {
        for (var answer in query.answers.v!) {
          // Correct?
          if (answer.correct.v == true) {
            score++;
            elapsedMs += answer.elapsedMs.v!;
          }
        }
      }

      /// We need at least the wanted count to win.
      if (score >= winningCount) {
        gdWinning = true;
      }
    } else {
      festenaoEnsureFields(
        query,
        fields: [apiQuizzSendResultQueryModel.username],
      );
      var quiz = await databaseService.fsQuiz(quizId).get(firestore);

      if (!quiz.exists) {
        throw ArgumentError('Missing quiz $quizId');
      }

      if (query.answers.isNotNull) {
        for (var answer in query.answers.v!) {
          var questionId = answer.questionId.v!;
          var answerId = answer.answerId.v;

          var correctAnswerId = quiz.getQuestionCorrectAnswerIdOrNull(
            questionId,
          );

          // Correct?
          if (correctAnswerId != null && correctAnswerId == answerId) {
            score++;
            elapsedMs += answer.elapsedMs.v!;
          }
        }
      }
    }
    String playerId;
    if (quizType == quizTypeGd) {
      var sessionId = query.sessionId.v!;
      var quizPlayerCollection = databaseService.fsGdQuizPlayerCollection(
        sessionId,
      );
      var player = FsGdQuizPlayer()
        ..quizId.v = quizId
        ..localDeviceId.fromCvField(query.localDeviceId)
        ..score.v = score
        ..elapsedMs.v = elapsedMs
        ..localTimestamp.setValue(localTimestamp);

      // Look for duplicate first
      var fsQuery = quizPlayerCollection
          .query()
          .where(fsGdQuizPlayerModel.quizId.name, isEqualTo: player.quizId.v)
          .where(fsGdQuizPlayerModel.score.name, isEqualTo: player.score.v)
          .where(
            fsGdQuizPlayerModel.elapsedMs.name,
            isEqualTo: player.elapsedMs.v,
          );

      fsQuery = fsQuery.where(
        fsGdQuizPlayerModel.localTimestamp.name,
        isEqualTo: localTimestamp,
      );
      if (localDeviceId != null) {
        fsQuery = fsQuery.where(
          fsGdQuizPlayerModel.localDeviceId.name,
          isEqualTo: localDeviceId,
        );
      }

      var foundPlayer = await fsQuery.limit(1).get(firestore);

      if (foundPlayer.isNotEmpty) {
        playerId = foundPlayer.first.id;
      } else {
        late CvDocumentReference<FsGdQuizPlayer> ref;

        await firestore.cvRunTransaction((txn) async {
          /// Generate a unique id
          while (true) {
            var uid = AutoIdGenerator.autoId();
            ref = databaseService.fsGdQuizPlayer(sessionId, uid);
            var doc = await txn.cvGet<FsGdQuizPlayer>(ref.path);
            if (!doc.exists) {
              break;
            }
          }
          if (gdWinning) {
            var goodieId = await databaseService.txnPlayerWinRandomGoodie(
              txn: txn,
              sessionId: sessionId,
              now: localTimestamp.toDateTime(),
            );
            player.won.v = goodieId;
          }

          txn.set(ref.raw(firestore), player.toMapWithServerTimestamp());
        });
        playerId = ref.id;
      }
    } else {
      var quizPlayerCollection = databaseService.fsQuizPlayerCollection(quizId);
      var player = FsQuizPlayer()
        ..validity.v = quizPlayerValidityUnknown
        ..username.fromCvField(query.username)
        ..avatar.fromCvField(query.avatar)
        ..score.v = score
        ..elapsedMs.v = elapsedMs
        ..localTimestamp.setValue(localTimestamp);

      // Look for duplicate first
      var fsQuery = quizPlayerCollection
          .query()
          .where(fsQuizPlayerModel.username.name, isEqualTo: player.username.v)
          .where(fsQuizPlayerModel.score.name, isEqualTo: player.score.v)
          .where(
            fsQuizPlayerModel.elapsedMs.name,
            isEqualTo: player.elapsedMs.v,
          );

      if (player.avatar.isNotNull) {
        fsQuery = fsQuery.where(
          fsQuizPlayerModel.avatar.name,
          isEqualTo: player.avatar.v,
        );
      }
      fsQuery = fsQuery.where(
        fsQuizPlayerModel.localTimestamp.name,
        isEqualTo: localTimestamp,
      );

      var foundPlayer = await fsQuery.limit(1).get(firestore);

      if (foundPlayer.isNotEmpty) {
        playerId = foundPlayer.first.id;
      } else {
        var ref = await quizPlayerCollection
            .raw(firestore)
            .add(player.toMapWithServerTimestamp());
        playerId = ref.id;
      }
    }
    return ApiQuizzSendResultResult()..playerId.v = playerId;
  }
}

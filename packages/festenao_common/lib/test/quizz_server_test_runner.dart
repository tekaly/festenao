import 'package:dev_test/test.dart';
import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_quizz.dart';
import 'package:festenao_common/test/quizz_test_fixtures.dart';
import 'package:tekartik_app_date/calendar_day.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// What the quizz api tests need: an api service reaching a server with a
/// `QuizzServerHandler`, and the firestore database it writes to for the
/// checks.
class QuizzTestContext {
  /// The api service.
  final TkCmsApiServiceBaseV2 apiService;

  /// The quizz database (same root as the server resolver for [projectId]).
  final QuizzFirestoreDatabase database;

  /// The project id.
  final String projectId;

  /// Creates the context.
  QuizzTestContext({
    required this.apiService,
    required this.database,
    required this.projectId,
  });

  /// The api client.
  late final apiClient = QuizzApiClient(
    apiService: apiService,
    projectId: projectId,
  );
}

/// The quizz api tests: a tv result and a gd result (with goodie) sent
/// through the api.
void testQuizzServerGroup(Future<QuizzTestContext> Function() initContext) {
  group('quizz api', () {
    late QuizzTestContext context;
    late QuizzFirestoreDatabase database;
    late Firestore firestore;
    setUpAll(() async {
      context = await initContext();
      database = context.database;
      firestore = database.firestore;
    });

    test('sendPlayerResult tv', () async {
      var apiClient = context.apiClient;
      await database
          .fsQuestion('q1')
          .set(
            firestore,
            FsQuestion()
              ..lastPlayedTimestamp.v = Timestamp.now()
              ..correctAnswerId.v = 'a1',
          );
      var now = Timestamp.now();
      var quiz = await database.createTvQuiz(now: DateTime.now());
      var quizId = quiz.id;
      var sessionId = quiz.sessionId.v!;
      var resultRequest = ApiQuizzSendResultQuery()
        ..username.v = 'u1'
        ..avatar.v = 'v1'
        ..quizId.v = quizId
        ..sessionId.v = sessionId
        ..localTimestamp.v = now.toIso8601String()
        ..answers.v = [
          CvQuizPlayerAnswer()
            ..answerId.v = 'a1'
            ..questionId.v = 'q1'
            ..elapsedMs.v = 150,
        ];
      var response = await apiClient.sendQuizResult(resultRequest);
      var playerId = response.playerId.v!;

      var player = await database.fsQuizPlayer(quizId, playerId).get(firestore);
      expect(player.toMap(), {
        'username': 'u1',
        'avatar': 'v1',
        'score': 1,
        'elapsedMs': 150,
        'timestamp': player.timestamp.v,
        'validity': 0,
        'localTimestamp': now,
      });

      // Send again, should return the same playerid
      response = await apiClient.sendQuizResult(resultRequest);
      expect(response.playerId.v!, playerId);

      await database.waitForPlayerResults(
        quizId: quizId,
        noNewPlayerDuration: const Duration(milliseconds: 100),
      );
      await database.computePlayersRanks(quizId: quizId);
      player = await database.fsQuizPlayer(quizId, playerId).get(firestore);
      expect(player.toMap(), {
        'username': 'u1',
        'avatar': 'v1',
        'score': 1,
        'elapsedMs': 150,
        'timestamp': player.timestamp.v,
        'rank': 1,
        'validity': 0,
        'localTimestamp': now,
      });
    });

    test('sendPlayerResult gd', () async {
      var apiClient = context.apiClient;
      var question1 = newQuizzTestQuestion1();
      var answerId = question1.correctAnswerId.v;
      var questionId = 'q1';
      await database.fsQuestion(questionId).set(firestore, question1);
      var deviceId = 'd1';
      var playersIds = <String>{};
      var quizId = 'testgd';
      var quiz = await database.createGdQuiz(
        now: DateTime.now(),
        tags: [quizzTestTag],
        quizId: quizId,
      );
      var now = Timestamp.now();
      var now1 = Timestamp.now();
      var now2 = Timestamp.fromDateTime(
        now1.toDateTime().add(const Duration(minutes: 1)),
      );
      var sessionId = quiz.sessionId.v!;

      ApiQuizzSendResultQuery newRequest({
        bool correct = true,
        int elasedMs = 0,
      }) {
        return ApiQuizzSendResultQuery()
          ..quizType.v = quiz.type.v
          ..sessionId.v = quiz.sessionId.v
          ..localTimestamp.v = now.toIso8601String()
          ..winningCount.v = 1
          ..quizId.v = quizId
          ..localDeviceId.v = deviceId
          ..answers.v = [
            CvQuizPlayerAnswer()
              ..correct.v = correct
              ..answerId.v = answerId
              ..questionId.v = questionId
              ..elapsedMs.v = elasedMs,
          ];
      }

      var resultRequest = newRequest(correct: true, elasedMs: 150)
        ..username.v = 'u1';
      await firestore.cvSet(
        database.fsSessionGoodiesConfig(sessionId).cv()
          ..copyFrom(newQuizzTestGoodiesConfig()),
      );
      var response = await apiClient.sendQuizResult(resultRequest);
      var playerId = response.playerId.v!;

      var player = await database
          .fsGdQuizPlayer(sessionId, playerId)
          .get(firestore);
      var playerMap = player.toMap();
      expect(playerMap, {
        'localDeviceId': 'd1',
        'quizId': quizId,
        'score': 1,
        'won': wonGoodie1,
        'elapsedMs': 150,
        'timestamp': player.timestamp.v,
        'localTimestamp': now,
      });

      // Send again, should return the same playerid
      response = await apiClient.sendQuizResult(resultRequest);
      expect(response.playerId.v!, playerId);

      player = await database
          .fsGdQuizPlayer(sessionId, playerId)
          .get(firestore);
      expect(player.toMap(), playerMap);

      // Send again new player different time
      resultRequest = newRequest(correct: true, elasedMs: 150)
        ..localTimestamp.v = now2.toIso8601String();
      response = await apiClient.sendQuizResult(resultRequest);
      var player2Id = response.playerId.v!;
      expect(player2Id, isNot(playerId));
      var player2 = await database
          .fsGdQuizPlayer(sessionId, player2Id)
          .get(firestore);
      playerMap = player2.toMap();
      expect(playerMap, {
        'localDeviceId': 'd1',
        'score': 1,
        'quizId': quizId,
        'elapsedMs': 150,
        'won': null, // 'no more goodies!',
        'timestamp': player2.timestamp.v,
        'localTimestamp': now2,
      });

      // Clear today
      var day = CalendarDay.fromTimestamp(now2.toDateTime(isUtc: true));
      await database.fsSessionGoodiesState(sessionId, day).delete(firestore);
      await firestore.cvSet(
        database.fsSessionGoodiesConfig(sessionId).cv()
          ..copyFrom(newQuizzTestGoodiesConfig())
          ..goodies.v!.first.dailyQuantity.v = 10,
      );
      // Send again new player
      resultRequest = newRequest(correct: true, elasedMs: 143);
      response = await apiClient.sendQuizResult(resultRequest);
      var player3Id = response.playerId.v!;
      expect(player3Id, isNot(player2Id));
      var player3 = await database
          .fsGdQuizPlayer(sessionId, player3Id)
          .get(firestore);
      playerMap = player3.toMap();
      expect(playerMap, {
        'localDeviceId': 'd1',
        'score': 1,
        'quizId': quizId,
        'elapsedMs': 143,
        'won': wonGoodie1,
        'timestamp': player3.timestamp.v,
        'localTimestamp': now,
      });

      // Send again new player
      resultRequest = newRequest(correct: true, elasedMs: 142);
      response = await apiClient.sendQuizResult(resultRequest);
      playerId = response.playerId.v!;
      expect(playersIds, isNot(contains(playerId)));
      playersIds.add(playerId);
      player = await database
          .fsGdQuizPlayer(sessionId, playerId)
          .get(firestore);
      playerMap = player.toMap();
      expect(playerMap, {
        'localDeviceId': 'd1',
        'score': 1,
        'quizId': quizId,
        'elapsedMs': 142,
        'won': wonGoodie1,
        'timestamp': player.timestamp.v,
        'localTimestamp': now,
      });

      // Send wrong
      resultRequest = newRequest(correct: false)..localDeviceId.v = 'dwrong1';
      response = await apiClient.sendQuizResult(resultRequest);
      playerId = response.playerId.v!;
      expect(playersIds, isNot(contains(playerId)));
      playersIds.add(playerId);
      player = await database
          .fsGdQuizPlayer(sessionId, playerId)
          .get(firestore);
      playerMap = player.toMap();
      expect(playerMap, {
        'localDeviceId': 'dwrong1',
        'score': 0,
        'quizId': quizId,
        'elapsedMs': 0,
        'timestamp': player.timestamp.v,
        'localTimestamp': now,
      });

      // Send wrong with winningCount lowered
      resultRequest = newRequest(correct: false)
        ..localDeviceId.v = 'dwrong2'
        ..winningCount.v = 0;
      response = await apiClient.sendQuizResult(resultRequest);
      playerId = response.playerId.v!;
      expect(playersIds, isNot(contains(playerId)));
      playersIds.add(playerId);
      player = await database
          .fsGdQuizPlayer(sessionId, playerId)
          .get(firestore);
      playerMap = player.toMap();
      expect(playerMap, {
        'localDeviceId': 'dwrong2',
        'score': 0,
        'quizId': quizId,
        'elapsedMs': 0,
        'won': wonGoodie1, // Ok!
        'timestamp': player.timestamp.v,
        'localTimestamp': now,
      });
    });

    test('full run tv (fake players, ranks)', () async {
      var apiClient = context.apiClient;
      var timeService = QuizzTimeService(timestampProvider: context.apiService)
        ..run();
      var sessionId = sessionIdTest;
      var controllerId = '_test';
      await database.fsQuestion('q1').set(firestore, newQuizzTestQuestion1());
      var quiz = await database.createTvQuiz(
        sessionId: sessionId,
        now: timeService.timestamp,
        config: FsQuizConfig()
          ..validationDelayMs.v = 1000
          ..questionCount.v = 1
          ..pauseDelayMs.v = 1000
          ..answerDelayMs.v = 1000
          ..preDelayMs.v = 0,
      );
      var quizId = quiz.id;
      try {
        var fakePlayerCount = 5;
        var quizController = AdminQuizPlayerController(
          controllerId: controllerId,
          apiClient: apiClient,
          timeService: timeService,
          quizId: quizId,
          databaseService: database,
          prefs: QuizzPrefsServiceMemory(),
        );
        quizController.fakePlayersCount = fakePlayerCount;
        await quizController.startQuiz(
          controllerId: controllerId,
          now: timeService.timestamp,
        );
        quizController.waitAndComputePlayerRanks(
          timeService.timestamp,
          auto: true,
        );
        var state = await quizController.stateValueStream.firstWhere(
          (element) => element.isDone,
        );
        expect(state.status.playersCount.v, fakePlayerCount);
        await database.archiveQuiz(quizId);
        state = await quizController.stateValueStream.firstWhere(
          (element) => element.isArchived,
        );
        expect(state.status.playersCount.v, fakePlayerCount);
        quizController.dispose();
      } finally {
        await database.archiveQuiz(quizId);
        timeService.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('full run gd (send result, goodie)', () async {
      var apiClient = context.apiClient;
      var timeService = QuizzTimeService(timestampProvider: context.apiService)
        ..run();
      var sessionId = sessionIdTest;
      var controllerId = '_test';
      var quizId = 'testgd0';
      await database.fsQuestion('q1').set(firestore, newQuizzTestQuestion1());
      await firestore.cvSet(
        database.fsSessionGoodiesConfig(sessionId).cv()
          ..copyFrom(newQuizzTestGoodiesConfig())
          ..goodies.v!.first.dailyQuantity.v = 10,
      );
      var now = timeService.timestamp;
      await database.createPlayableGdQuiz(
        controllerId: controllerId,
        sessionId: sessionId,
        quizId: quizId,
        now: now,
        config: FsQuizConfig()
          ..validationDelayMs.v = 3000
          ..questionCount.v = 1
          ..preDelayMs.v = 0,
      );
      var prefs = QuizzPrefsServiceMemory();
      var quizController = QuizPlayerController(
        timeService: timeService,
        controllerId: controllerId,
        apiClient: apiClient,
        quizId: quizId,
        databaseService: database,
        prefs: prefs,
      );
      try {
        var state = await quizController.stateValueStream.first;
        expect(state, isA<QuizRunnerStateGd>());
        expect(state.questionCount, 1);
        // Answer correctly
        var question = state.questions.first;
        prefs.prefsUpdateQuizLocalStatus((status) {
          status.winningCount.v = 1;
          status.addAnswer(
            CvPrefsQuizPlayerAnswer()
              ..questionId.v = question.questionId.v
              ..answerId.v = question.correctAnswerId.v
              ..correct.v = true
              ..elapsedMs.v = 100,
          );
        });
        var stateStream = quizController.sendResult(now);
        var won = await stateStream
            .where((event) => event is SendResultControllerStateWon)
            .cast<SendResultControllerStateWon>()
            .first;
        expect(won.wonData.won, wonGoodie1);
      } finally {
        quizController.dispose();
        timeService.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}

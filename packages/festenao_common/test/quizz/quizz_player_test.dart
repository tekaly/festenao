import 'package:festenao_common/festenao_quizz.dart';
import 'package:festenao_common/firebase/firebase_memory.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_common_utils/num_utils.dart';
import 'package:test/test.dart';

Future<void> main() async {
  var firebaseContext = await festenaoInitFirebaseMemory();
  var databaseService = QuizzFirestoreDatabase(
    firestore: firebaseContext.firestore,
    rootDocument: festenaoProjectQuizzRootDocument(
      app: 'test',
      projectId: 'p1',
    ),
  );
  group('score_controller', () {
    test('waitForPlayerResults no player', () async {
      var controllerId = '1';
      var quizId = 'quiz1';
      var scoreController = ScoreComputerController(
        databaseService,
        controllerId: controllerId,
      );
      var stepMs = 5;
      var durationMs = (stepMs * 5).boundedMin(20);
      var sw = Stopwatch()..start();
      var future = scoreController.waitForPlayerResults(
        quizId: quizId,
        noPlayerDuration: Duration(milliseconds: durationMs),
        sleepStepMs: stepMs,
      );
      await scoreController.stateValueStream.firstWhere((element) {
        return element.lastReceivedPlayerCount == 0;
      });
      await future;
      expect(sw.elapsedMilliseconds, greaterThan(durationMs * .9));
      expect(
        sw.elapsedMilliseconds,
        lessThan((durationMs * 1.5).boundedMin(1000)),
      );
      scoreController.dispose();
    });
    test('waitForPlayerResults one player', () async {
      var controllerId = '1';
      var quizId = 'quiz1';
      var playerId = 'playerId';
      var quizPlayer = databaseService.fsQuizPlayer(quizId, playerId).cv()
        ..validity.v = quizPlayerValidityUnknown
        ..score.v = 1
        ..timestamp.v = twoThousandsTimestamp
        ..elapsedMs.v = 200;
      await databaseService.quizSavePlayer(quizId, quizPlayer);
      var scoreController = ScoreComputerController(
        databaseService,
        controllerId: controllerId,
      );
      var stepMs = 5;
      var durationMs = (stepMs * 5).boundedMin(20);
      var sw = Stopwatch()..start();
      var future = scoreController.waitForPlayerResults(
        quizId: quizId,
        noNewPlayerDuration: Duration(milliseconds: durationMs),
        sleepStepMs: stepMs,
      );
      await scoreController.stateValueStream.firstWhere((element) {
        return element.lastReceivedPlayerCount == 1;
      });
      await future;
      expect(sw.elapsedMilliseconds, greaterThan(durationMs * .9));
      expect(
        sw.elapsedMilliseconds,
        lessThan((durationMs * 1.5).boundedMin(1000)),
      );
      scoreController.dispose();
    });

    test('waitForPlayerResults multi player', () async {
      var controllerId = '1';
      var quizId = 'quiz1';
      var playerId = 'playerId';
      var quizPlayer = databaseService.fsQuizPlayer(quizId, playerId).cv()
        ..validity.v = quizPlayerValidityUnknown
        ..score.v = 2
        ..timestamp.v = twoThousandsTimestamp
        ..elapsedMs.v = 200;
      await databaseService.quizSavePlayer(quizId, quizPlayer);
      var scoreController = ScoreComputerController(
        databaseService,
        controllerId: controllerId,
      );
      var stepMs = 5;
      var durationMs = (stepMs * 5).boundedMin(20);
      var addingPlayerDurationMs = durationMs * 4;
      var sw = Stopwatch()..start();
      var future = scoreController.waitForPlayerResults(
        quizId: quizId,
        noNewPlayerDuration: Duration(milliseconds: durationMs),
        sleepStepMs: stepMs,
      );
      () async {
        var index = 0;
        while (sw.isRunning &&
            sw.elapsedMilliseconds < addingPlayerDurationMs) {
          var playerId = 'playerId${(index + 1).toString().padLeft(4, '0')}';
          await sleep(stepMs);
          var quizPlayer = databaseService.fsQuizPlayer(quizId, playerId).cv()
            ..validity.v = quizPlayerValidityUnknown
            ..score.v = 1
            ..timestamp.v = twoThousandsTimestamp
            ..elapsedMs.v = 200;
          await databaseService.quizSavePlayer(quizId, quizPlayer);
          index++;
        }
      }().unawait();

      await future;
      expect(sw.elapsedMilliseconds, greaterThan(addingPlayerDurationMs * .9));
      expect(
        sw.elapsedMilliseconds,
        lessThan((addingPlayerDurationMs * 1.5).boundedMin(1000)),
      );
      sw.stop();
      scoreController.dispose();
    });
  });
  group('gd controller', () {
    test('create/run', () async {
      var firestore = firebaseContext.firestore;
      var prefs = QuizzPrefsServiceMemory();
      var fsQuestionRef = databaseService.fsQuestion('q1');
      await fsQuestionRef.set(
        databaseService.firestore,
        FsQuestion()
          ..lastPlayedTimestamp.v = neverPlayedTimestamp
          ..text.v = (CvLocalizedText()
            ..en.v = 'en1'
            ..fr.v = 'fr1')
          ..answers.v = [
            CvAnswer()
              ..text.v = (CvLocalizedText()
                ..en.v = 'en2'
                ..fr.v = 'fr2')
              ..id.v = 'a1',
          ]
          ..correctAnswerId.v = 'a1',
      );
      var startTimestamp = DateTime.utc(2023, 07, 20);
      var sessionId = 's1';
      var quiz = await databaseService.createGdQuiz(
        sessionId: sessionId,
        now: startTimestamp,
        uid: '-N_pFXrxdPNeVAilUi53',
        config: FsQuizConfig()..preDelayMs.v = quizConfigPreDelayMsDefault,
      );
      var quizId = quiz.id;
      expect(quiz.type.v, quizTypeGd);
      var question = await fsQuestionRef.get(firestore);
      // Not marked as played for gd
      expect(question.lastPlayedTimestamp.v, Timestamp(0, 0));

      // start
      await databaseService.startQuiz(
        quizId: quizId,
        now: startTimestamp,
        controllerId: 'c1',
      );
      var status = await databaseService
          .fsQuizInfoStatus(quizId)
          .get(firestore);
      expect(status.toMap(), {
        'controllerId': 'c1',
        'startTimestamp': Timestamp.fromDateTime(startTimestamp),
        'status': 'playing',
      });

      var controllerId = 'c001';
      var controller = UserQuizPlayerController(
        controllerId: controllerId,
        databaseService: databaseService,
        quizId: quizId,
        apiClient: null,
        prefs: prefs,
      );
      var state = await controller.stateValueStream.first;
      expect(state, isA<QuizRunnerStateGd>());
      expect(state.isValid, isTrue);
      expect(state.questionCount, 1);
      var stateNow = state.now(startTimestamp);
      expect(stateNow.questionIndex, 0);
      expect(stateNow.isPost, isFalse);
      // The local copy has been created
      expect(prefs.prefsGetQuizLocalCopy()!.quizId.v, quizId);
      expect(prefs.prefsGetQuizLocalStatus()!.deviceId.v, controllerId);
      controller.dispose();

      // A new controller reads from prefs only
      controller = UserQuizPlayerController(
        controllerId: controllerId,
        databaseService: databaseService,
        quizId: quizId,
        apiClient: null,
        prefs: prefs,
      );
      state = await controller.stateValueStream.first;
      expect(state, isA<QuizRunnerStateGd>());
      expect(state.questionCount, 1);
      controller.dispose();
    });
  });
}

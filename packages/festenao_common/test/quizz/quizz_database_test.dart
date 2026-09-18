import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_quizz.dart';
import 'package:festenao_common/firebase/firebase_memory.dart';
import 'package:festenao_common/test/quizz_test_fixtures.dart';
import 'package:tekartik_app_date/calendar_day.dart';
import 'package:test/test.dart';

Future<void> main() async {
  var firebaseContext = await festenaoInitFirebaseMemory();
  var firestore = firebaseContext.firestore;
  var databaseService = QuizzFirestoreDatabase(
    firestore: firestore,
    rootDocument: festenaoProjectQuizzRootDocument(
      app: 'test',
      projectId: 'p1',
    ),
  );
  test('paths', () {
    expect(
      databaseService.fsQuestion('q1').path,
      'app/test/project/p1/data/quizz/questions/q1',
    );
    expect(
      databaseService.fsQuizInfoStatus('z1').path,
      'app/test/project/p1/data/quizz/quizzes/z1/infos/status',
    );
    expect(
      databaseService.fsSessionGoodiesConfig('s1').path,
      'app/test/project/p1/data/quizz/sessions/s1/infos/goodiesConfig',
    );
    var topLevel = QuizzFirestoreDatabase(firestore: firestore);
    expect(topLevel.fsQuestion('q1').path, 'questions/q1');
  });
  test('create/start/pause/resume/cancel', () async {
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
    var quiz = await databaseService.createTvQuiz(
      sessionId: sessionId,
      now: startTimestamp,
      uid: '-N_pFXrxdPNeVAilUi53',
      config: FsQuizConfig()..preDelayMs.v = quizConfigPreDelayMsDefault,
    );
    var quizId = quiz.id;
    var quizMap = quiz.toMap();
    var encoded =
        ((quizMap['questions'] as List).first as Map)['correctAnswerIdEnc']
            as String;
    expect(quizMap, {
      'uid': '-N_pFXrxdPNeVAilUi53',
      'questions': [
        {
          'id': 'q1',
          'text': {'en': 'en1', 'fr': 'fr1'},
          'answers': [
            {
              'id': 'a1',
              'text': {'en': 'en2', 'fr': 'fr2'},
            },
          ],
          'correctAnswerIdEnc': encoded,
        },
      ],
      'createdTimestamp': Timestamp.fromDateTime(startTimestamp),
      'preDelayMs': quizConfigPreDelayMsDefault,
      'sessionId': sessionId,
      'type': 'tv',
    });
    var readQuiz = await databaseService.fsQuiz(quizId).get(firestore);
    expect(readQuiz.getQuestionCorrectAnswerId('q1'), 'a1');
    var question = await fsQuestionRef.get(firestore);
    expect(question.toMap(), {
      'text': {'en': 'en1', 'fr': 'fr1'},
      'answers': [
        {
          'id': 'a1',
          'text': {'en': 'en2', 'fr': 'fr2'},
        },
      ],
      'correctAnswerId': 'a1',
      'lastPlayedTimestamp': Timestamp.fromDateTime(startTimestamp),
    });

    // start
    await databaseService.startQuiz(
      quizId: quizId,
      now: startTimestamp,
      controllerId: 'c1',
    );
    var status = await databaseService.fsQuizInfoStatus(quizId).get(firestore);
    expect(status.toMap(), {
      'controllerId': 'c1',
      'startTimestamp': Timestamp.fromDateTime(startTimestamp),
      'status': 'playing',
    });
    var session = await databaseService.fsSession(sessionId).get(firestore);
    expect(session.activeQuizId.v, quizId);

    // control
    await databaseService.controlQuiz(quizId: quizId, controllerId: 'c2');
    status = await databaseService.fsQuizInfoStatus(quizId).get(firestore);
    expect(status.toMap(), {
      'controllerId': 'c2',
      'startTimestamp': Timestamp.fromDateTime(startTimestamp),
      'status': 'playing',
    });

    // pause
    var pauseDateTime = DateTime.utc(2023, 07, 20, 1);
    await databaseService.pauseQuiz(quizId: quizId, now: pauseDateTime);

    status = await databaseService.fsQuizInfoStatus(quizId).get(firestore);
    expect(status.toMap(), {
      'controllerId': 'c2',
      'startTimestamp': Timestamp.fromDateTime(startTimestamp),
      'pausedStartTimestamp': Timestamp.fromDateTime(pauseDateTime),
      'status': 'paused',
    });

    // resume
    var resumeDateTime = DateTime.utc(2023, 07, 20, 1, 1);
    // result pre-computed
    var newStartDateTime = DateTime.utc(2023, 07, 20, 0, 1);
    await databaseService.resumeQuiz(quizId: quizId, now: resumeDateTime);

    status = await databaseService.fsQuizInfoStatus(quizId).get(firestore);
    expect(status.toMap(), {
      'controllerId': 'c2',
      'startTimestamp': Timestamp.fromDateTime(newStartDateTime),
      'pausedStartTimestamp': null,
      'status': 'playing',
    });

    var controllerId = 'c001';
    var controller = QuizPlayerController(
      controllerId: controllerId,
      databaseService: databaseService,
      quizId: quizId,
      apiClient: null,
      prefs: QuizzPrefsServiceMemory(),
    );
    var state = await controller.stateValueStream.first;
    var stateNow = state.now(newStartDateTime);
    expect(stateNow.isPre, isTrue);
    expect(stateNow.questionIndex, isNull);
    stateNow = state.now(
      newStartDateTime.add(
        Duration(milliseconds: quizConfigPreDelayMsDefault - 1),
      ),
    );
    expect(stateNow.isPre, isTrue);
    stateNow = state.now(
      newStartDateTime.add(Duration(milliseconds: quizConfigPreDelayMsDefault)),
    );
    expect(stateNow.isPre, isFalse);
    expect(stateNow.questionIndex, 0);
    stateNow = state.now(
      newStartDateTime.add(
        Duration(
          milliseconds:
              quizConfigPreDelayMsDefault + quizConfigAnswerDelayMsDefault,
        ),
      ),
    );
    expect(stateNow.isPost, isTrue);
    expect(stateNow.questionIndex, isNull);

    var now = newStartDateTime.add(
      Duration(
        milliseconds:
            quizConfigPreDelayMsDefault + quizConfigAnswerDelayMsDefault - 1,
      ),
    );
    stateNow = state.now(now);

    expect(stateNow.questionIndex, 0);
    expect(
      stateNow.getElapsedPreMs(),
      quizConfigPreDelayMsDefault + quizConfigAnswerDelayMsDefault - 1,
    );
    controller.dispose();
    await databaseService.quizOffset(quizId: quizId, ms: -1);

    controller = QuizPlayerController(
      databaseService: databaseService,
      controllerId: controllerId,
      quizId: quizId,
      apiClient: null,
      prefs: QuizzPrefsServiceMemory(),
    );
    state = await controller.stateValueStream.first;
    stateNow = state.now(now);
    expect(
      stateNow.getElapsedPreMs(),
      quizConfigPreDelayMsDefault + quizConfigAnswerDelayMsDefault - 2,
    );
    controller.dispose();

    await databaseService.waitForPlayerResults(
      quizId: quizId,
      noNewPlayerDuration: const Duration(milliseconds: 100),
    );
    var count = await databaseService.computePlayersRanks(quizId: quizId);
    await databaseService.quizUpdatePlayerCountAndMarkAsDone(quizId, count);

    await databaseService.archiveQuiz(quizId);
    var archives = await databaseService.fsQuizArchiveCollection.get(firestore);
    var archive = archives.first;

    expect(archives, [
      FsQuizArchive()
        ..path = archive.path
        ..sessionId.v = sessionId
        ..playersCount.v = 0
        ..startTimestamp.v = Timestamp.fromDateTime(
          newStartDateTime.add(const Duration(milliseconds: 1)),
        )
        ..quizId.v = quizId,
    ]);
    status = await databaseService.fsQuizInfoStatus(quizId).get(firestore);
    expect(status.exists, isTrue);

    await databaseService.deleteQuiz(quizId);
    archives = await databaseService.fsQuizArchiveCollection.get(firestore);
    expect(archives.length, 1);
    status = await databaseService.fsQuizInfoStatus(quizId).get(firestore);
    expect(status.exists, isFalse);
  });
  test('cancel active quiz', () async {
    await databaseService
        .fsQuestion('q1')
        .set(firestore, newQuizzTestQuestion1());
    var sessionId = 's_cancel';
    var now = DateTime.utc(2024, 1, 1);
    var quiz = await databaseService.createTvQuiz(
      sessionId: sessionId,
      now: now,
      config: FsQuizConfig()..questionCount.v = 1,
    );
    await databaseService.makeQuizPreActive(
      quizId: quiz.id,
      now: now,
      controllerId: 'c1',
    );
    var session = await databaseService.fsSession(sessionId).get(firestore);
    expect(session.activeQuizId.v, quiz.id);
    await databaseService.cancelActiveQuiz(sessionId: sessionId);
    session = await databaseService.fsSession(sessionId).get(firestore);
    expect(session.activeQuizId.v, isNull);
    var status = await databaseService.fsQuizInfoStatus(quiz.id).get(firestore);
    expect(status.isCancelled, isTrue);
  });
  test('questions add/set/delete', () async {
    var db = QuizzFirestoreDatabase(
      firestore: firestore,
      rootDocument: festenaoProjectQuizzRootDocument(
        app: 'test',
        projectId: 'p_questions',
      ),
    );
    var id = await db.addQuestion(newQuizzTestQuestion1());
    var question = await db.fsQuestion(id).get(firestore);
    expect(question.lastPlayedTimestamp.v, neverPlayedTimestamp);
    expect(question.correctAnswerId.v, 'A');
    await db.setQuestion(id, newQuizzTestQuestion2());
    question = await db.fsQuestion(id).get(firestore);
    expect(question.text.v!.fr.v, 'Question 2 fr');
    expect((await db.getQuestions()).length, 1);
    expect((await db.getQuestions(tags: ['other'])).length, 0);
    await db.deleteQuestion(id);
    expect((await db.getQuestions()).length, 0);
  });
  test('playerWinRandomGoodie', () async {
    var now = DateTime.utc(2024, 1, 1);
    var sessionId = 'session_test_1';
    expect(
      await databaseService.playerWinRandomGoodie(
        sessionId: sessionId,
        now: now,
      ),
      isNull,
    );
    var config = databaseService.fsSessionGoodiesConfig(sessionId).cv()
      ..goodies.v = [
        CvGdGoodieConfig()
          ..id.v = 'g1'
          ..dailyQuantity.v = 1,
      ]
      ..winningChance.v = 1;
    await databaseService.firestore.cvSet(config);
    var goodie = await databaseService.playerWinRandomGoodie(
      sessionId: sessionId,
      now: now,
    );
    expect(goodie, 'g1');
    expect(
      await databaseService
          .fsSessionGoodiesState(sessionId, CalendarDay.fromTimestamp(now))
          .get(firestore),
      FsGdGoodiesState()
        ..goodies.v = [
          CvGdGoodieState()
            ..id.v = 'g1'
            ..count.v = 1
            ..used.v = 1,
        ],
    );
    expect(
      await databaseService.playerWinRandomGoodie(
        sessionId: sessionId,
        now: now,
      ),
      isNull,
    );
  });
  test('multi playerWinRandomGoodie', () async {
    var now = DateTime.utc(2024, 1, 3);
    var sessionId = 'session_test_2';
    expect(
      await databaseService.playerWinRandomGoodie(
        sessionId: sessionId,
        now: now,
      ),
      isNull,
    );

    var config = databaseService.fsSessionGoodiesConfig(sessionId).cv()
      ..goodies.v = [
        CvGdGoodieConfig()
          ..id.v = 'g1'
          ..dailyQuantity.v = 2,
        CvGdGoodieConfig()
          ..id.v = 'g2'
          ..dailyQuantity.v = 3,
      ]
      ..winningChance.v = 1;
    await databaseService.firestore.cvSet(config);
    var goodies = <String?>[];
    for (var i = 0; i < 6; i++) {
      var goodie = await databaseService.playerWinRandomGoodie(
        sessionId: sessionId,
        now: now,
      );
      goodies.add(goodie);
    }
    expect(goodies.last, isNull);
    expect(goodies.where((element) => element == 'g1').length, 2);
    expect(goodies.where((element) => element == 'g2').length, 3);
  });
}

import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_quizz.dart';
import 'package:festenao_common/firebase/firebase_memory.dart';
import 'package:festenao_common/test/quizz_test_fixtures.dart';
import 'package:test/test.dart';

/// The send result command, called on the handler directly (the api round
/// trip is in quizz_server_memory_test.dart).
Future<void> main() async {
  var firebaseContext = await festenaoInitFirebaseMemory();
  var firestore = firebaseContext.firestore;
  var database = QuizzFirestoreDatabase(
    firestore: firestore,
    rootDocument: festenaoProjectQuizzRootDocument(
      app: 'test',
      projectId: 'p1',
    ),
  );
  var handler = QuizzServerHandler(
    options: QuizzServerHandlerOptions(
      firestore: firestore,
      rootDocumentResolver: festenaoQuizzRootDocumentResolver(app: 'test'),
    ),
  );
  Future<String> send(ApiQuizzSendResultQuery query) async {
    var request = ApiRequest(command: apiCommandQuizzSendResult)
      ..setQuery(query);
    var result = await handler.onSendResultCommand(request);
    return result.playerId.v!;
  }

  /// A one question answer (q1, correct).
  List<CvQuizPlayerAnswer> correctAnswers({int elapsedMs = 100}) => [
    CvQuizPlayerAnswer()
      ..questionId.v = 'q1'
      ..answerId.v = 'A'
      ..elapsedMs.v = elapsedMs,
  ];

  ApiQuizzSendResultQuery tvQuery(String quizId) => ApiQuizzSendResultQuery()
    ..projectId.v = 'p1'
    ..quizId.v = quizId
    ..username.v = 'u1'
    ..localTimestamp.v = Timestamp.now().toIso8601String()
    ..answers.v = correctAnswers();

  ApiQuizzSendResultQuery gdQuery(String quizId, String sessionId) =>
      ApiQuizzSendResultQuery()
        ..projectId.v = 'p1'
        ..quizType.v = quizTypeGd
        ..quizId.v = quizId
        ..sessionId.v = sessionId
        ..localDeviceId.v = 'd1'
        ..localTimestamp.v = Timestamp.now().toIso8601String()
        ..answers.v = correctAnswers();

  Matcher throwsInvalidArgument() => throwsA(
    isA<ApiException>()
        .having((e) => e.error?.code.v, 'code', 'invalid-argument')
        .having((e) => e.error?.noRetry.v, 'noRetry', isTrue),
  );

  setUpAll(() async {
    await database.fsQuestion('q1').set(firestore, newQuizzTestQuestion1());
    await database.createTvQuiz(now: DateTime.now(), quizId: 'tv1');
    await database.createGdQuiz(
      now: DateTime.now(),
      tags: [quizzTestTag],
      quizId: 'gd1',
      sessionId: 'sessionA',
    );
    // An existing player document, that a quizId with a / would name.
    await database
        .fsQuizPlayer('tv1', 'victim')
        .set(firestore, FsQuizPlayer()..username.v = 'v');
    // Session B has goodies, always won.
    await firestore.cvSet(
      database.fsSessionGoodiesConfig('sessionB').cv()
        ..copyFrom(newQuizzTestGoodiesConfig()),
    );
  });

  group('ids', () {
    test('quizId with a /', () async {
      await expectLater(
        send(tvQuery('tv1/players/victim')),
        throwsInvalidArgument(),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
    test('projectId with a /', () async {
      await expectLater(
        send(tvQuery('tv1')..projectId.v = 'p1/data/quizz/quizzes/tv1'),
        throwsInvalidArgument(),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
    test('dataId with a /', () async {
      await expectLater(
        send(tvQuery('tv1')..dataId.v = 'quizz/x/y'),
        throwsInvalidArgument(),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
    test('sessionId with a /', () async {
      await expectLater(
        send(gdQuery('gd1', 'sessionA/players/x/y')),
        throwsInvalidArgument(),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('gd', () {
    test('the session of the quiz, not the client one', () async {
      await expectLater(
        send(gdQuery('gd1', 'sessionB')),
        throwsInvalidArgument(),
      );
      expect(
        await database.fsGdQuizPlayerCollection('sessionB').count(firestore),
        0,
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
    test('a tv quiz sent as gd', () async {
      await expectLater(
        send(gdQuery('tv1', 'sessionB')),
        throwsInvalidArgument(),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
    test('a gd quiz sent as tv', () async {
      await expectLater(send(tvQuery('gd1')), throwsInvalidArgument());
    }, timeout: const Timeout(Duration(seconds: 30)));
    test('the quiz session', () async {
      var playerId = await send(gdQuery('gd1', 'sessionA'));
      var player = await database
          .fsGdQuizPlayer('sessionA', playerId)
          .get(firestore);
      expect(player.score.v, 1);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  test('a negative elapsedMs is stored as 0', () async {
    var playerId = await send(
      tvQuery('tv1')
        ..username.v = 'negative'
        ..answers.v = correctAnswers(elapsedMs: -1000000),
    );
    var player = await database.fsQuizPlayer('tv1', playerId).get(firestore);
    expect(player.score.v, 1);
    expect(player.elapsedMs.v, 0);
  }, timeout: const Timeout(Duration(seconds: 30)));
}

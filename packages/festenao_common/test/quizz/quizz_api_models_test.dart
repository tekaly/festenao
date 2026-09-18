import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_quizz.dart';
import 'package:test/test.dart';

void main() {
  initQuizzBuilders();
  group('quizz api_models', () {
    test('ApiQuizzSendResultQuery', () {
      var map = (ApiQuizzSendResultQuery()..fillModel(cvFirestoreFillOptions1))
          .toMap();
      var validation = map['validation'] as String;
      expect(map, {
        'projectId': 'text_1',
        'dataId': 'text_2',
        'sessionId': 'text_3',
        'quizType': 'text_4',
        'quizId': 'text_5',
        'username': 'text_6',
        'avatar': 'text_7',
        'answers': [
          {
            'questionId': 'text_8',
            'answerId': 'text_9',
            'elapsedMs': 10,
            'correct': false,
          },
        ],
        'validation': validation,
        'localTimestamp': 'text_13',
        'winningCount': 14,
        'localDeviceId': 'text_15',
      });
      var quiz = ApiQuizzSendResultQuery()
        ..quizId.v = '1'
        ..answers.v = <CvQuizPlayerAnswer>[];
      map = quiz.toMap();
      expect(map.keys, ['quizId', 'answers', 'validation']);
      quiz = ApiQuizzSendResultQuery()..fromMap(map);
      expect(quiz.toMap(), map);

      quiz = ApiQuizzSendResultQuery()
        ..quizId.v = '1'
        ..localTimestamp.v = 'some'
        ..answers.v = <CvQuizPlayerAnswer>[
          CvQuizPlayerAnswer()..elapsedMs.v = 3,
        ];
      map = quiz.toMap();
      expect(map['answers'], [
        {'elapsedMs': 3},
      ]);
      quiz = ApiQuizzSendResultQuery()..fromMap(map);
      expect(quiz.toMap(), map);

      // Tampered quiz id
      expect(
        () => ApiQuizzSendResultQuery()..fromMap({...map, 'quizId': 'dummy'}),
        throwsA(isA<ArgumentError>()),
      );
      // Tampered timestamp
      expect(
        () =>
            ApiQuizzSendResultQuery()
              ..fromMap({...map, 'localTimestamp': 'dummy'}),
        throwsA(isA<ArgumentError>()),
      );
      // Tampered answers
      expect(
        () => ApiQuizzSendResultQuery()
          ..fromMap({
            ...map,
            'answers': [
              {'elapsedMs': 4},
            ],
          }),
        throwsA(isA<ArgumentError>()),
      );
    });
    test('ApiQuizzSendResultResult', () {
      expect(
        (newModel().cv<ApiQuizzSendResultResult>()
              ..fillModel(cvFirestoreFillOptions1))
            .toMap(),
        {'playerId': 'text_1'},
      );
    });
  });
}

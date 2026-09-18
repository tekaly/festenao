import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_quizz.dart';
import 'package:test/test.dart';

// Restart each time
CvFillOptions get fillOptions => cvFirestoreFillOptions1;

void main() {
  initQuizzBuilders();
  group('quizz fs_models', () {
    test('FsQuestion', () {
      expect((FsQuestion()..fillModel(fillOptions)).toMap(), {
        'text': {'en': 'text_1', 'fr': 'text_2'},
        'answers': [
          {
            'id': 'text_3',
            'text': {'en': 'text_4', 'fr': 'text_5'},
          },
        ],
        'tags': ['text_6'],
        'correctAnswerId': 'text_7',
        'lastPlayedTimestamp': Timestamp(8, 0),
        'disabled': false,
      });
    });
    test('FsSession', () {
      expect((newModel().cv<FsSession>()..fillModel(fillOptions)).toMap(), {
        'name': 'text_1',
        'activeQuizId': 'text_2',
      });
    });
    test('FsQuiz', () {
      expect((newModel().cv<FsQuiz>()..fillModel(fillOptions)).toMap(), {
        'uid': 'text_1',
        'questions': [
          {
            'id': 'text_2',
            'text': {'en': 'text_3', 'fr': 'text_4'},
            'answers': [
              {
                'id': 'text_5',
                'text': {'en': 'text_6', 'fr': 'text_7'},
              },
            ],
            'tags': ['text_8'],
            'correctAnswerIdEnc': 'text_9',
          },
        ],
        'createdTimestamp': Timestamp(10, 0),
        'preDelayMs': 11,
        'answerDelayMs': 12,
        'pauseDelayMs': 13,
        'validationDelayMs': 14,
        'questionCount': 15,
        'questionWinningCount': 16,
        'tags': ['text_17'],
        'sessionId': 'text_18',
        'type': 'text_19',
      });
      var quiz = FsQuiz()
        ..uid.v = '1'
        ..questions.v = [CvQuizEncodedQuestion()..correctAnswerId.v = '2']
        ..createdTimestamp.v = Timestamp(1, 2);
      expect(quiz.questions.v!.first.correctAnswerId.v, '2');
      var map = quiz.toMap();
      var encoded =
          ((map['questions'] as List).first as Map)['correctAnswerIdEnc']
              as String;
      expect(encoded, isNot('2'));
      expect(map, {
        'uid': '1',
        'questions': [
          {'correctAnswerIdEnc': encoded},
        ],
        'createdTimestamp': Timestamp(1, 2),
      });
      quiz = FsQuiz()..fromMap(map);
      expect(quiz.questions.v!.first.correctAnswerId.v, '2');
      expect(quiz.toMap(), map);

      // Another uid cannot decode
      quiz = FsQuiz()..fromMap({...map, 'uid': '3'});
      expect(quiz.questions.v!.first.correctAnswerId.v, isNull);

      var fsQuizConfig = FsQuizConfig()..preDelayMs.v = 1;
      var fsQuiz = FsQuiz();
      fsQuiz.preDelayMs.fromCvField(fsQuizConfig.preDelayMs);
      expect(fsQuiz.preDelayMs.v, 1);
      fsQuiz = FsQuiz()..copyConfigFrom(fsQuizConfig);
      expect(fsQuiz.preDelayMs.v, 1);
      expect(fsQuiz.answerDelayMs.v, isNull);
    });
    test('FsQuizPlayer', () {
      expect((FsQuizPlayer()..fillModel(fillOptions)).toMap(), {
        'username': 'text_1',
        'avatar': 'text_2',
        'score': 3,
        'elapsedMs': 4,
        'rank': 5,
        'timestamp': Timestamp(6, 0),
        'validity': 7,
        'localTimestamp': Timestamp(8, 0),
      });
    });
    test('FsGdQuizPlayer', () {
      expect(
        (cvBuildModel<FsGdQuizPlayer>({})..fillModel(fillOptions)).toMap(),
        {
          'localDeviceId': 'text_1',
          'score': 2,
          'elapsedMs': 3,
          'quizId': 'text_4',
          'localTimestamp': Timestamp(5, 0),
          'won': 'text_6',
          'day': 'text_7',
          'timestamp': Timestamp(8, 0),
        },
      );
    });
    test('FsQuizConfig', () {
      expect((newModel().cv<FsQuizConfig>()..fillModel(fillOptions)).toMap(), {
        'preDelayMs': 1,
        'answerDelayMs': 2,
        'pauseDelayMs': 3,
        'validationDelayMs': 4,
        'questionCount': 5,
        'questionWinningCount': 6,
        'tags': ['text_7'],
      });
    });
    test('FsQuizStatus', () {
      expect((newModel().cv<FsQuizStatus>()..fillModel(fillOptions)).toMap(), {
        'controllerId': 'text_1',
        'startTimestamp': Timestamp(2, 0),
        'pausedStartTimestamp': Timestamp(3, 0),
        'status': 'text_4',
        'playersCount': 5,
        'doneTimestamp': Timestamp(6, 0),
      });
    });
    test('LocalCopy', () {
      var quiz = FsQuiz()
        ..uid.v = '1'
        ..questions.v = [CvQuizEncodedQuestion()..correctAnswerId.v = '2'];
      var encoded =
          ((quiz.toMap()['questions'] as List).first
                  as Map)['correctAnswerIdEnc']
              as String;
      var localCopy = PrefsQuizLocalCopy()
        ..uid.v = '1'
        ..questions.v = [CvQuizEncodedQuestion()..correctAnswerId.v = '2'];
      localCopy.toMap();
      expect(localCopy.questions.v!.first.toMap(), {
        'correctAnswerIdEnc': encoded,
      });
    });
    test('CvLocalizedText', () {
      var text = CvLocalizedText()
        ..fr.v = ' fr '
        ..en.v = '';
      expect(text.frText, 'fr');
      expect(text.enText, isNull);
      expect(text.defaultText, 'fr');
      expect(text.textForLanguageCode('en'), 'fr');
      expect(text.isValid(), isTrue);
    });
  });
}

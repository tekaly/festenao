import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_quizz.dart';

/// A test question with 3 answers, `A` being the correct one.
FsQuestion newQuizzTestQuestion1() => FsQuestion()
  ..lastPlayedTimestamp.v = neverPlayedTimestamp
  ..text.v = (CvLocalizedText()
    ..fr.v = 'Question simple'
    ..en.v = 'Simple question')
  ..answers.v = [
    CvAnswer()
      ..id.v = 'A'
      ..text.v = (CvLocalizedText()
        ..fr.v = 'Réponse juste'
        ..en.v = 'Correct answer'),
    CvAnswer()
      ..id.v = 'B'
      ..text.v = (CvLocalizedText()
        ..fr.v = 'Réponse fausse'
        ..en.v = 'Wrong answer'),
    CvAnswer()
      ..id.v = 'C'
      ..text.v = (CvLocalizedText()
        ..fr.v = 'Autre réponse fausse'
        ..en.v = 'Another wrong answer'),
  ]
  ..correctAnswerId.v = 'A'
  ..tags.v = [quizzTestTag];

/// A second test question.
FsQuestion newQuizzTestQuestion2() => FsQuestion()
  ..copyFrom(newQuizzTestQuestion1())
  ..text.v = (CvLocalizedText()
    ..fr.v = 'Question 2 fr'
    ..en.v = 'Question 2 en');

/// A test goodies config with a single daily goodie, always won.
FsGdGoodiesConfig newQuizzTestGoodiesConfig() => FsGdGoodiesConfig()
  ..goodies.v = [
    (CvGdGoodieConfig()
      ..id.v = wonGoodie1
      ..text.v = (CvLocalizedText()
        ..en.v = 'Goodie 1'
        ..fr.v = 'Cadeau 1')
      ..dailyQuantity.v = 1),
  ]
  ..winningChance.v = 1;

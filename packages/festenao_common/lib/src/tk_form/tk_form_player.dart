import 'package:tekartik_common_utils/env_utils.dart';

import 'tk_form.dart';
import 'tk_form_question.dart';
import 'tk_form_question_answer.dart';
import 'tk_form_question_player.dart';

/// Form Player
abstract class TkFormPlayer {
  /// The form being played
  TkFormPlayerForm get form;

  /// Form id
  String get id;

  /// Question count
  int get questionCount;

  /// Current question index (0 based), start with -1
  int get currentQuestionIndex;

  /// Get question by index
  TkFormPlayerQuestion getQuestion(int index);

  /// Get last known answer by index, (null if not answered)
  TkFormPlayerQuestionAnswer? getAnswer(int index);

  /// Should skip question
  bool shouldSkip(int index);

  /// Set answer
  void setAnswer(int index, TkFormPlayerQuestionAnswer? answer);

  /// Get question player by index
  TkFormQuestionPlayer getQuestionPlayer(int index);
}

/// Form Player Base
abstract class TkFormPlayerBase implements TkFormPlayer {
  @override
  final TkFormPlayerForm form;
  @override
  int currentQuestionIndex = -1;

  /// question list
  final List<TkFormPlayerQuestion> questions;

  /// answer list
  late final List<TkFormPlayerQuestionAnswer?> answers = List.filled(
    questionCount,
    null,
  );
  @override
  TkFormPlayerQuestion getQuestion(int index) => questions[index];

  @override
  TkFormPlayerQuestionAnswer? getAnswer(int index) => answers[index];
  @override
  final String id;

  @override
  int get questionCount => questions.length;

  /// Constructor
  TkFormPlayerBase({
    required this.id,
    required this.questions,
    required this.form,
  }) {
    if (isDebug) {
      var ids = questions.ids;
      if (ids.length != ids.toSet().length) {
        throw ArgumentError('Duplicate question ids in: $ids');
      }
    }
  }

  @override
  void setAnswer(int index, TkFormPlayerQuestionAnswer? answer) {
    answers[index] = answer;
  }

  @override
  TkFormQuestionPlayer getQuestionPlayer(int index) =>
      TkFormQuestionPlayer(formPlayer: this, index: index);

  @override
  bool shouldSkip(int index) {
    return false;
  }
}

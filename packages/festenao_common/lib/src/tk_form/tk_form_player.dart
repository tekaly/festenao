import 'package:tekartik_common_utils/env_utils.dart';

import 'tk_form.dart';
import 'tk_form_question.dart';
import 'tk_form_question_answer.dart';
import 'tk_form_question_player.dart';

/// Abstraction for a form player which manages questions and answers.
abstract class TkFormPlayer {
  /// The form being played.
  TkFormPlayerForm get form;

  /// Unique identifier for this player instance.
  String get id;

  /// Total number of questions in the form.
  int get questionCount;

  /// Current question index (0-based). Starts at -1 before the first question.
  int get currentQuestionIndex;

  /// Returns the question at the given [index].
  TkFormPlayerQuestion getQuestion(int index);

  /// Returns the last known answer for the question at [index], or null if none.
  TkFormPlayerQuestionAnswer? getAnswer(int index);

  /// Whether the question at [index] should be skipped.
  bool shouldSkip(int index);

  /// Sets the answer for the question at [index].
  void setAnswer(int index, TkFormPlayerQuestionAnswer? answer);

  /// Returns a [TkFormQuestionPlayer] for the question at [index].
  TkFormQuestionPlayer getQuestionPlayer(int index);
}

/// Base implementation of [TkFormPlayer] that stores questions and answers.
abstract class TkFormPlayerBase implements TkFormPlayer {
  @override
  final TkFormPlayerForm form;
  @override
  int currentQuestionIndex = -1;

  /// The list of questions in the form.
  final List<TkFormPlayerQuestion> questions;

  /// The list of answers corresponding to the questions. May contain nulls.
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

  /// Creates a new base form player with the given [id], [questions], and [form].
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

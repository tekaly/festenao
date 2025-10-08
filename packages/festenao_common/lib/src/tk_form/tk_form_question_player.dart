import 'tk_form_player.dart';
import 'tk_form_question.dart';
import 'tk_form_question_answer.dart';

/// Represents a question player which exposes a question and its answer for a form player.
abstract class TkFormQuestionPlayer {
  /// The form player owning this question.
  TkFormPlayer get formPlayer;

  /// The question associated with this player.
  TkFormPlayerQuestion get question;

  /// The last known answer for this question, or null if unanswered.
  TkFormPlayerQuestionAnswer? get answer;

  /// Sets the answer for this question.
  set answer(TkFormPlayerQuestionAnswer? answer);

  /// Whether this question should be skipped.
  bool shouldSkip();

  /// Factory to create a question player for [formPlayer] at [index].
  factory TkFormQuestionPlayer({
    required TkFormPlayer formPlayer,
    required int index,
  }) {
    return _TkFormQuestionPlayerBase(formPlayer: formPlayer, index: index);
  }
}

/// Base implementation of [TkFormQuestionPlayer].
class _TkFormQuestionPlayerBase implements TkFormQuestionPlayer {
  @override
  final TkFormPlayer formPlayer;

  /// question index
  final int index;

  /// Constructor
  _TkFormQuestionPlayerBase({required this.formPlayer, required this.index});

  @override
  TkFormPlayerQuestionAnswer? get answer => formPlayer.getAnswer(index);

  @override
  TkFormPlayerQuestion get question => formPlayer.getQuestion(index);

  @override
  set answer(TkFormPlayerQuestionAnswer? answer) {
    formPlayer.setAnswer(index, answer);
  }

  @override
  bool shouldSkip() {
    return formPlayer.shouldSkip(index);
  }
}

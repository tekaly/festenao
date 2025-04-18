import 'tk_form_player.dart';
import 'tk_form_question.dart';
import 'tk_form_question_answer.dart';

/// Form Player
abstract class TkFormQuestionPlayer {
  /// The form being played
  TkFormPlayer get formPlayer;

  /// Get question by index
  TkFormPlayerQuestion get question;

  /// Get last known answer, (null if not answered)
  TkFormPlayerQuestionAnswer? get answer;

  /// Set answer
  set answer(TkFormPlayerQuestionAnswer? answer);

  /// True if the question should be skipped
  bool shouldSkip();

  /// Constructor
  factory TkFormQuestionPlayer({
    required TkFormPlayer formPlayer,
    required int index,
  }) {
    return _TkFormQuestionPlayerBase(formPlayer: formPlayer, index: index);
  }
}

/// Form Player Base
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

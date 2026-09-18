import 'package:festenao_common/festenao_quizz.dart';
import 'package:flutter/material.dart';

/// A question with its answers as buttons.
///
/// [selectedAnswerId] is the player pick, [correctAnswerId] reveals the
/// correct answer (once the question is over). [onAnswer] is called on tap
/// while enabled (null disables the buttons).
class QuizzQuestionWidget extends StatelessWidget {
  /// The question.
  final CvQuestionMixin question;

  /// The language code (`en`, `fr`), null for the default text.
  final String? languageCode;

  /// The player pick.
  final String? selectedAnswerId;

  /// The correct answer, when revealed.
  final String? correctAnswerId;

  /// Called on tap, null disables the buttons.
  final void Function(String answerId)? onAnswer;

  /// The question header (`3 / 10`).
  final String? header;

  /// Creates the widget.
  const QuizzQuestionWidget({
    super.key,
    required this.question,
    this.languageCode,
    this.selectedAnswerId,
    this.correctAnswerId,
    this.onAnswer,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var answers = question.answers.v ?? <CvAnswer>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              header!,
              style: theme.textTheme.labelLarge,
              textAlign: TextAlign.center,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            question.text.v?.textForLanguageCode(languageCode) ?? '',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        for (var answer in answers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: QuizzAnswerButton(
              answer: answer,
              languageCode: languageCode,
              selected: answer.id.v == selectedAnswerId,
              correct: correctAnswerId == null
                  ? null
                  : answer.id.v == correctAnswerId,
              onTap: onAnswer == null ? null : () => onAnswer!(answer.id.v!),
            ),
          ),
      ],
    );
  }
}

/// An answer button, highlighted when selected, green/red when the correct
/// answer is revealed.
class QuizzAnswerButton extends StatelessWidget {
  /// The answer.
  final CvAnswer answer;

  /// The language code.
  final String? languageCode;

  /// True if picked by the player.
  final bool selected;

  /// True/false once revealed, null before.
  final bool? correct;

  /// On tap, null disables the button.
  final VoidCallback? onTap;

  /// Creates the button.
  const QuizzAnswerButton({
    super.key,
    required this.answer,
    this.languageCode,
    this.selected = false,
    this.correct,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;
    Color? background;
    Color? foreground;
    if (correct == true) {
      background = Colors.green;
      foreground = Colors.white;
    } else if (correct == false && selected) {
      background = Colors.red;
      foreground = Colors.white;
    } else if (selected) {
      background = colorScheme.primary;
      foreground = colorScheme.onPrimary;
    }
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background,
        disabledForegroundColor: foreground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onPressed: onTap,
      child: Row(
        children: [
          Text(
            answer.id.v ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(answer.text.v?.textForLanguageCode(languageCode) ?? ''),
          ),
        ],
      ),
    );
  }
}

import 'package:festenao_common/festenao_quizz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'quizz_state_builder.dart';

/// The admin control bar of a quiz: previous, pause, resume, next, force
/// end, plus the status.
class QuizzControlWidget extends StatelessWidget {
  /// The controller (admin side).
  final QuizPlayerController controller;

  /// True to compute the ranks automatically at the end.
  final bool auto;

  /// Creates the widget.
  const QuizzControlWidget({
    super.key,
    required this.controller,
    this.auto = false,
  });

  QuizzTimeService get _timeService => controller.timeService;

  @override
  Widget build(BuildContext context) {
    return QuizzStateNowBuilder(
      controller: controller,
      builder: (context, stateNow) {
        if (stateNow == null) {
          return const Center(child: CircularProgressIndicator());
        }
        var valid = stateNow.isValid;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (valid)
              Wrap(
                children: [
                  IconButton(
                    tooltip: 'Previous',
                    onPressed: () {
                      controller.previous(_timeService.timestamp);
                    },
                    icon: const Icon(Icons.skip_previous),
                  ),
                  IconButton(
                    tooltip: 'Pause',
                    onPressed: () {
                      controller.pause(_timeService.timestamp);
                    },
                    icon: const Icon(Icons.pause),
                  ),
                  IconButton(
                    tooltip: 'Resume',
                    onPressed: () {
                      controller.resume(_timeService.timestamp);
                    },
                    icon: const Icon(Icons.play_arrow),
                  ),
                  IconButton(
                    tooltip: 'Next',
                    onPressed: () {
                      controller.next(_timeService.timestamp);
                    },
                    icon: const Icon(Icons.skip_next),
                  ),
                  IconButton(
                    tooltip: 'Compute the ranks now',
                    onPressed: () {
                      controller.waitAndComputePlayerRanks(
                        _timeService.timestamp,
                        auto: true,
                        force: true,
                      );
                    },
                    icon: const Icon(Icons.score),
                  ),
                  if (kDebugMode)
                    IconButton(
                      tooltip: 'Cancel',
                      onPressed: () {
                        controller.cancelQuiz();
                      },
                      icon: const Icon(Icons.cancel),
                    ),
                ],
              ),
            QuizzStatusWidget(
              stateNow: stateNow,
              auto: auto,
              controller: controller,
            ),
          ],
        );
      },
    );
  }
}

/// The status line of a quiz: idle, qr code display, question n, pause,
/// end, ranks computed.
class QuizzStatusWidget extends StatefulWidget {
  /// The controller.
  final QuizPlayerController controller;

  /// True to compute the ranks automatically at the end.
  final bool auto;

  /// The time dependent view.
  final QuizPlayerStateNow stateNow;

  /// Creates the widget.
  const QuizzStatusWidget({
    super.key,
    required this.stateNow,
    required this.auto,
    required this.controller,
  });

  @override
  State<QuizzStatusWidget> createState() => _QuizzStatusWidgetState();
}

class _QuizzStatusWidgetState extends State<QuizzStatusWidget> {
  var _endOfQuizStarted = false;

  void _endOfQuiz() {
    if (_endOfQuizStarted) {
      return;
    }
    _endOfQuizStarted = true;
    var now = widget.controller.timeService.timestamp;
    widget.controller.waitAndComputePlayerRanks(now, auto: widget.auto);
  }

  @override
  Widget build(BuildContext context) {
    var stateNow = widget.stateNow;
    if (!stateNow.isPlayingOrPaused) {
      if (stateNow.isIdle) {
        return const ListTile(title: Text('Waiting to start'));
      }
      if (stateNow.isDoneOrArchived) {
        return ListTile(
          title: const Text('Ranks computed'),
          subtitle: stateNow.isExpired
              ? const Text('Quiz expired')
              : const Text('Quiz done'),
        );
      } else {
        if (!stateNow.isValid) {
          return const SizedBox.shrink();
        }
        if (stateNow.isCancelled) {
          return const ListTile(title: Text('Quiz cancelled'));
        }
        return const SizedBox.shrink();
      }
    } else if (stateNow.isPre) {
      return ListTile(
        title: const Text('QR code display'),
        subtitle: Text(quizzFormatMs(stateNow.getRemainingPreMs())),
      );
    } else if (stateNow.isPost) {
      if (widget.auto) {
        _endOfQuiz();
      }
      var scoreComputeStateStream =
          widget.controller.scoreComputerStateValueStream;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('End'),
            subtitle: Text(quizzFormatMs(stateNow.getPostMs())),
          ),
          if (scoreComputeStateStream != null)
            StreamBuilder(
              stream: scoreComputeStateStream,
              builder: (_, snapshot) {
                var value = snapshot.data;
                if (value == null) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  title: const Text('Waiting for the players'),
                  subtitle: Text(
                    '${value.lastReceivedPlayerCount ?? 0} player(s)'
                    '${value.waitingForNewPlayersDone == true ? ', validation' : ''}'
                    '${value.waitingForValidationDone == true ? ', computing' : ''}',
                  ),
                );
              },
            ),
        ],
      );
    } else {
      var questionIndex = stateNow.questionIndex;
      if (questionIndex != null) {
        var remainingMs = stateNow.getQuestionAnswerRemainingMs(questionIndex);
        if (remainingMs >= 0) {
          return ListTile(
            title: Text('Question ${questionIndex + 1}'),
            subtitle: Text(
              '${quizzFormatMs(stateNow.getQuestionAnswerDurationMs(questionIndex))} / ${quizzFormatMs(remainingMs)}',
            ),
          );
        } else {
          return ListTile(
            title: Text('Waiting for question ${questionIndex + 2}'),
            subtitle: Text(
              '${quizzFormatMs(stateNow.getQuestionPauseDurationMs(questionIndex))} / ${quizzFormatMs(stateNow.getQuestionPauseRemainingMs(questionIndex))}',
            ),
          );
        }
      }
    }
    return const SizedBox.shrink();
  }
}

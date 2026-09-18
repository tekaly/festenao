import 'package:festenao_common/festenao_quizz.dart';
import 'package:flutter/material.dart';

import 'quizz_player_utils.dart';
import 'quizz_progress_widgets.dart';

/// The players to validate at the end of a quiz, best first, with a
/// validate toggle per player and a "validate the 3 first" button, under a
/// progress bar of the validation delay ([onEnd] once over).
class QuizzValidationWidget extends StatefulWidget {
  /// The database.
  final QuizzFirestoreDatabase database;

  /// The time service.
  final QuizzTimeService timeService;

  /// The quiz.
  final FsQuiz quiz;

  /// Called when the validation delay is over.
  final VoidCallback onEnd;

  /// True to show the scores and times.
  final bool advancedMode;

  /// Creates the widget.
  const QuizzValidationWidget({
    super.key,
    required this.database,
    required this.timeService,
    required this.quiz,
    required this.onEnd,
    this.advancedMode = false,
  });

  @override
  State<QuizzValidationWidget> createState() => _QuizzValidationWidgetState();
}

class _QuizzValidationWidgetState extends State<QuizzValidationWidget> {
  late QuizProgressController controller;

  String get quizId => widget.quiz.id;

  @override
  void initState() {
    var now = widget.timeService.timestampMs;
    var duration = widget.quiz.validationDelayMsOrDefault;
    controller = QuizProgressController(startMs: now, endMs: now + duration);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var limit = 100;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QuizzFiniteProgressIndicator(
              onEnd: widget.onEnd,
              controller: controller,
              timeService: widget.timeService,
            ),
            StreamBuilder<List<FsQuizPlayer>>(
              stream: widget.database.orderedPlayersNoValidityStream(
                quizId,
                limit: limit,
              ),
              builder: (context, snapshot) {
                var players = snapshot.data ?? <FsQuizPlayer>[];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: const Text('Players'),
                            subtitle: Text(
                              players.length >= limit
                                  ? '> ${limit - 1}'
                                  : players.length.toString(),
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: () {
                            widget.database.validatePlayers(
                              quizId: quizId,
                              limit: 3,
                            );
                          },
                          child: const Text('Validate the 3 first'),
                        ),
                      ],
                    ),
                    for (var player in players)
                      QuizzToValidatePlayerWidget(
                        database: widget.database,
                        advancedMode: widget.advancedMode,
                        quizId: quizId,
                        player: player,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A player row with its validate toggle.
class QuizzToValidatePlayerWidget extends StatelessWidget {
  /// The database.
  final QuizzFirestoreDatabase database;

  /// The quiz id.
  final String quizId;

  /// True to show the score and time.
  final bool advancedMode;

  /// The player.
  final FsQuizPlayer player;

  /// Creates the row.
  const QuizzToValidatePlayerWidget({
    super.key,
    required this.database,
    required this.player,
    required this.quizId,
    required this.advancedMode,
  });

  void _validatePlayer(int validity) {
    database.validatePlayer(
      quizId: quizId,
      playerId: player.id,
      quizPlayerValidity: validity,
    );
  }

  @override
  Widget build(BuildContext context) {
    var isValid = player.validity.v == quizPlayerValidityValid;
    return Row(
      children: [
        Expanded(
          child: Text(quizzFixDisplayNameString(player.username.v ?? '')),
        ),
        if (advancedMode) ...[
          SizedBox(width: 32, child: Text((player.score.v ?? 0).toString())),
          SizedBox(
            width: 64,
            child: Text((player.elapsedMs.v ?? 0).toString()),
          ),
        ],
        Padding(
          padding: const EdgeInsets.all(2.0),
          child: Ink(
            decoration: ShapeDecoration(
              color: isValid ? Colors.green : Colors.grey,
              shape: const CircleBorder(),
            ),
            child: IconButton(
              onPressed: () {
                if (isValid) {
                  _validatePlayer(quizPlayerValidityUnknown);
                } else {
                  _validatePlayer(quizPlayerValidityValid);
                }
              },
              icon: const Icon(Icons.check, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

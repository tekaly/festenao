import 'package:festenao_common/festenao_quizz.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_rx_utils/app_rx_utils.dart';

import 'quizz_periodic_builder.dart';

/// Builds from the time dependent view of a [QuizPlayerController], rebuilt
/// on every state change and every [period] (the timing moves on its own).
///
/// [builder] gets a null view until the quiz and its status are read.
class QuizzStateNowBuilder extends StatelessWidget {
  /// The controller.
  final QuizPlayerController controller;

  /// The rebuild period.
  final Duration period;

  /// The builder.
  final Widget Function(BuildContext context, QuizPlayerStateNow? stateNow)
  builder;

  /// Creates the builder.
  const QuizzStateNowBuilder({
    super.key,
    required this.controller,
    required this.builder,
    this.period = const Duration(milliseconds: 100),
  });

  @override
  Widget build(BuildContext context) {
    return ValueStreamBuilder<QuizRunnerState>(
      stream: controller.stateValueStream,
      builder: (context, snapshot) {
        var state = snapshot.data;
        if (state == null) {
          return builder(context, null);
        }
        return QuizzPeriodicBuilder(
          duration: period,
          builder: (context) {
            return builder(
              context,
              state.now(controller.timeService.timestamp),
            );
          },
        );
      },
    );
  }
}

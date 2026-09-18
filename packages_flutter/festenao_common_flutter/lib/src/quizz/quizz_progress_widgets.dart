import 'dart:async';

import 'package:festenao_common/festenao_quizz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_common_utils/num_utils.dart';

/// A linear progress indicator.
class QuizzProgressIndicator extends StatelessWidget {
  /// The progress (0 to 1).
  final double progress;

  /// Creates the indicator.
  const QuizzProgressIndicator({super.key, required this.progress});
  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(value: progress);
  }
}

/// A progress indicator animated from the current progress of [controller]
/// to its end, calling [onEnd] once done.
class QuizzFiniteProgressIndicator extends StatefulWidget {
  /// Called at the end.
  final VoidCallback onEnd;

  /// The step timing.
  final QuizProgressController controller;

  /// The time service.
  final QuizzTimeService timeService;

  /// Creates the indicator.
  const QuizzFiniteProgressIndicator({
    super.key,
    required this.onEnd,
    required this.controller,
    required this.timeService,
  });

  @override
  State<QuizzFiniteProgressIndicator> createState() =>
      _QuizzFiniteProgressIndicatorState();
}

class _QuizzFiniteProgressIndicatorState
    extends State<QuizzFiniteProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    controller =
        AnimationController(
          vsync: this,
          duration: Duration(milliseconds: widget.controller.durationMs),
        )..addListener(() {
          setState(() {});
        });
    controller
        .forward(
          from: widget.controller.getProgress(widget.timeService.timestampMs),
        )
        .whenComplete(() {
          widget.onEnd();
        });
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuizzProgressIndicator(progress: controller.value);
  }
}

/// The progress of a step: a paused bar or an animated one.
class QuizzStepProgressIndicator extends StatelessWidget {
  /// The step timing.
  final QuizProgressController controller;

  /// The time service.
  final QuizzTimeService timeService;

  /// Creates the indicator.
  const QuizzStepProgressIndicator({
    super.key,
    required this.controller,
    required this.timeService,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.isValid) {
      return const SizedBox.shrink();
    }
    if (controller.isPaused) {
      return QuizzProgressIndicator(progress: controller.pausedProgress);
    }
    return QuizzFiniteProgressIndicator(
      // A new widget per step, so the animation restarts
      key: ValueKey(controller.startMs),
      onEnd: () {},
      controller: controller,
      timeService: timeService,
    );
  }
}

/// A text in a rounded box, with an optional shadow box.
class QuizzRoundedText extends StatelessWidget {
  /// The text.
  final String text;

  /// The width.
  final double width;

  /// The font size.
  final double fontSize;

  /// The shadow color if any.
  final Color? shadowColor;

  /// The text color (black by default).
  final Color? textColor;

  /// The box decoration (white rounded by default).
  final BoxDecoration? decoration;

  /// The height (1.8 times the font size by default).
  final double? height;

  /// The font weight (w900 by default).
  final FontWeight? fontWeight;

  /// Creates the text.
  const QuizzRoundedText(
    this.text, {
    super.key,
    required this.width,
    required this.fontSize,
    this.textColor,
    this.height,
    this.decoration,
    this.fontWeight,
    this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    var height = this.height ?? fontSize * 1.8;
    return Stack(
      children: [
        if (shadowColor != null)
          Padding(
            padding: EdgeInsets.only(left: fontSize * .2),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(fontSize),
                color: shadowColor,
              ),
              child: SizedBox(width: width, height: height),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(top: fontSize * .2),
          child: Container(
            decoration:
                decoration ??
                BoxDecoration(
                  borderRadius: BorderRadius.circular(fontSize),
                  color: Colors.white,
                ),
            child: SizedBox(
              width: width,
              height: height,
              child: Center(
                child: Text(
                  text,
                  textScaler: TextScaler.noScaling,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor ?? Colors.black,
                    fontSize: fontSize,
                    fontWeight: fontWeight ?? FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The remaining time of a step (`mm:ss`), refreshed every second.
class QuizzProgressTimeWidget extends StatefulWidget {
  /// The step timing.
  final QuizProgressController controller;

  /// The time service.
  final QuizzTimeService timeService;

  /// The font size.
  final double fontSize;

  /// The width.
  final double width;

  /// The shadow color if any.
  final Color? shadowColor;

  /// Creates the widget.
  const QuizzProgressTimeWidget({
    super.key,
    required this.controller,
    required this.timeService,
    required this.fontSize,
    required this.width,
    this.shadowColor,
  });

  @override
  State<QuizzProgressTimeWidget> createState() =>
      _QuizzProgressTimeWidgetState();
}

class _QuizzProgressTimeWidgetState extends State<QuizzProgressTimeWidget> {
  Timer? timer;
  QuizProgressController get controller => widget.controller;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void setTimer() {
    var remaining = controller
        .getRemainingMs(widget.timeService.timestampMs)
        .boundedMin(0);
    if (remaining >= 1 && !controller.isPaused) {
      var remainingNextSecondMs = (remaining % 1000) + 1;
      timer?.cancel();
      timer = Timer(Duration(milliseconds: remainingNextSecondMs), () {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  // Add 10 ms to handle near second drawing
  String? get displayTime {
    if (controller.isPaused && !kDebugMode) {
      return null;
    }
    var remaining = controller
        .getRemainingMs(widget.timeService.timestampMs + 10)
        .boundedMin(0);
    return quizzFormatRemainingMsTime(remaining);
  }

  @override
  Widget build(BuildContext context) {
    var displayTime = this.displayTime;
    setTimer();
    if (displayTime == null) {
      return const SizedBox.shrink();
    }

    return QuizzRoundedText(
      displayTime,
      fontSize: widget.fontSize,
      width: widget.width,
      shadowColor: widget.shadowColor,
    );
  }
}

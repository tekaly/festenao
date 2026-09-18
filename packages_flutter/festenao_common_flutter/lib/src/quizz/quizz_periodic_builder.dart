import 'dart:async';

import 'package:flutter/material.dart';

/// Rebuilds [builder] every [duration].
class QuizzPeriodicBuilder extends StatefulWidget {
  /// The period.
  final Duration duration;

  /// The builder.
  final WidgetBuilder builder;

  /// Creates the builder.
  const QuizzPeriodicBuilder({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<QuizzPeriodicBuilder> createState() => _QuizzPeriodicBuilderState();
}

class _QuizzPeriodicBuilderState extends State<QuizzPeriodicBuilder> {
  late Timer timer;

  @override
  void initState() {
    timer = Timer.periodic(widget.duration, (_) {
      if (mounted) {
        setState(() {});
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(builder: widget.builder);
  }
}

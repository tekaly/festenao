import 'package:festenao_common/festenao_quizz.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_rx_utils/app_rx_utils.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';

/// The server synchronized time (`hh:mm:ss`), refreshed every second.
class QuizzTimeWidget extends StatefulWidget {
  /// The time service.
  final QuizzTimeService timeService;

  /// The text style.
  final TextStyle? style;

  /// Creates the widget.
  const QuizzTimeWidget({super.key, required this.timeService, this.style});

  @override
  State<QuizzTimeWidget> createState() => _QuizzTimeWidgetState();
}

class _QuizzTimeWidgetState extends State<QuizzTimeWidget> {
  final _timeSubject = BehaviorSubject<DateTime>();
  @override
  void initState() {
    () async {
      try {
        await widget.timeService.fixedOnce.timeout(const Duration(seconds: 3));
      } catch (_) {}
      while (mounted) {
        var time = widget.timeService.timestamp.toLocal();
        _timeSubject.add(time);
        var ms = time.millisecond;
        await sleep(1000 - ms);
      }
    }();
    super.initState();
  }

  @override
  void dispose() {
    _timeSubject.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueStreamBuilder(
      stream: _timeSubject,
      builder: (_, snapshot) {
        var time = snapshot.data;
        if (time != null) {
          // Round
          if (time.millisecond > 750) {
            time = time.add(Duration(milliseconds: 1000 - time.millisecond));
          }
          return Text(quizzFormatTime(time), style: widget.style);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

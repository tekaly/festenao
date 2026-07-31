import 'package:festenao_common/log/log.dart';
import 'package:flutter/material.dart';
import 'log_playground.dart';
import 'log_viewer.dart';

/// Global default logger instance for demo and app-wide logging.
FestenaoLogger? _globalFestenaoLogger;

/// Accessor for global default logger instance.
FestenaoLogger get globalFestenaoLogger {
  _globalFestenaoLogger ??= FestenaoLogger(
    storage: MemoryLogStorage(),
    loggerName: 'festenao.app',
  );
  return _globalFestenaoLogger!;
}

/// Combined screen offering Tab navigation between [FestenaoLogViewer] (Explorer)
/// and [FestenaoLogPlayground] (Playground & Stress Testing).
class FestenaoLogScreen extends StatelessWidget {
  /// Optional logger client instance.
  final FestenaoLogger? logger;

  /// Optional custom screen title.
  final String? title;

  /// Creates a new [FestenaoLogScreen].
  const FestenaoLogScreen({super.key, this.logger, this.title});

  @override
  Widget build(BuildContext context) {
    final effectiveLogger = logger ?? globalFestenaoLogger;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title ?? 'Festenao Logs'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.explore), text: 'Log Explorer'),
              Tab(icon: Icon(Icons.science), text: 'Log Playground'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FestenaoLogViewer(storage: effectiveLogger.storage),
            FestenaoLogPlayground(logger: effectiveLogger),
          ],
        ),
      ),
    );
  }
}

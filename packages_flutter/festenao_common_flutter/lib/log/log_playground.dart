import 'dart:math';
import 'package:festenao_common/log/log.dart';
import 'package:flutter/material.dart';
import 'log_viewer.dart';

/// Screen wrapper for [FestenaoLogPlayground].
class FestenaoLogPlaygroundScreen extends StatelessWidget {
  /// Logger client instance.
  final FestenaoLogger logger;

  /// Optional custom screen title.
  final String? title;

  /// Creates a new [FestenaoLogPlaygroundScreen].
  const FestenaoLogPlaygroundScreen({
    super.key,
    required this.logger,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Log Playground'),
        actions: [
          IconButton(
            icon: const Icon(Icons.remove_red_eye),
            tooltip: 'Open Log Viewer',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FestenaoLogViewerScreen(storage: logger.storage),
                ),
              );
            },
          ),
        ],
      ),
      body: FestenaoLogPlayground(logger: logger),
    );
  }
}

/// Interactive playground widget for emitting test logs, running stress tests,
/// and testing storage limits, rotation, and reader performance.
class FestenaoLogPlayground extends StatefulWidget {
  /// Logger client instance.
  final FestenaoLogger logger;

  /// Creates a new [FestenaoLogPlayground] widget.
  const FestenaoLogPlayground({
    super.key,
    required this.logger,
  });

  @override
  State<FestenaoLogPlayground> createState() => _FestenaoLogPlaygroundState();
}

class _FestenaoLogPlaygroundState extends State<FestenaoLogPlayground> {
  LogLevel _selectedLevel = LogLevel.info;
  final TextEditingController _loggerNameController =
      TextEditingController(text: 'kiosk.terminal');
  final TextEditingController _messageController = TextEditingController(
      text: 'User completed checkout successfully at kiosk borne-42');
  bool _includeExtraJson = true;

  bool _isStressTesting = false;
  double _stressProgress = 0.0;
  int _emittedCount = 0;

  @override
  void dispose() {
    _loggerNameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _emitLog() {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;

    final extra = _includeExtraJson
        ? {
            'deviceId': 'borne-42',
            'sessionId': 'sess_${Random().nextInt(90000) + 10000}',
            'payload': {
              'itemCount': 3,
              'totalAmount': 15.50,
              'currency': 'EUR',
            },
          }
        : null;

    widget.logger.log(
      level: _selectedLevel,
      loggerName: _loggerNameController.text.trim().isEmpty
          ? null
          : _loggerNameController.text.trim(),
      message: msg,
      extra: extra,
    );

    setState(() => _emittedCount++);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Emitted ${_selectedLevel.name} log #$_emittedCount'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _runStressTest(int count) async {
    setState(() {
      _isStressTesting = true;
      _stressProgress = 0.0;
    });

    final random = Random();
    final levels = [
      LogLevel.debug,
      LogLevel.info,
      LogLevel.warning,
      LogLevel.error,
      LogLevel.fatal,
    ];

    for (var i = 0; i < count; i++) {
      final lvl = levels[random.nextInt(levels.length)];
      final isErr = lvl >= LogLevel.error;
      widget.logger.log(
        level: lvl,
        loggerName: 'stress.test.worker_${random.nextInt(5)}',
        message: 'Stress test log entry #${i + 1} of $count - payload data string',
        error: isErr ? 'SimulatedException: Error code ${random.nextInt(500)}' : null,
        stackTrace: isErr
            ? 'StackTrace #0 main.dart:42\nStackTrace #1 logger.dart:105\nStackTrace #2 stress_runner.dart:${random.nextInt(200)}'
            : null,
        extra: {
          'index': i + 1,
          'randomSeed': random.nextInt(100000),
        },
      );

      if (i % 25 == 0 || i == count - 1) {
        setState(() {
          _stressProgress = (i + 1) / count;
          _emittedCount += 25;
        });
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    setState(() => _isStressTesting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Completed stress test: emitted $count logs!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Emit Test Log Record',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Log Level: '),
                      const SizedBox(width: 8),
                      DropdownButton<LogLevel>(
                        value: _selectedLevel,
                        items: const [
                          DropdownMenuItem(
                              value: LogLevel.debug, child: Text('DEBUG')),
                          DropdownMenuItem(
                              value: LogLevel.info, child: Text('INFO')),
                          DropdownMenuItem(
                              value: LogLevel.warning, child: Text('WARNING')),
                          DropdownMenuItem(
                              value: LogLevel.error, child: Text('ERROR')),
                          DropdownMenuItem(
                              value: LogLevel.fatal, child: Text('FATAL')),
                        ],
                        onChanged: (lvl) {
                          if (lvl != null) {
                            setState(() => _selectedLevel = lvl);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _loggerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Logger Name',
                      hintText: 'e.g. kiosk.auth',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Log Message',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          _messageController.text = 'Kiosk ping OK';
                        },
                        child: const Text('Preset Short'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          _messageController.text =
                              'User borne-42 completed order #98231 with 3 items';
                        },
                        child: const Text('Preset Medium'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          _messageController.text =
                              'System Exception in Payment Gateway\nTraceback: Stack #0 payment_service.dart:45\nStack #1 checkout_bloc.dart:102';
                        },
                        child: const Text('Preset Long'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Include Embedded JSON Metadata'),
                    value: _includeExtraJson,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() => _includeExtraJson = val ?? true);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('Emit Single Log Record'),
                      onPressed: _emitLog,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stress Test Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stress Testing & Storage Rotation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Rapidly emit batch log records to test 10MB segment creation, rotation, master DB indexing, and reader performance.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  if (_isStressTesting) ...[
                    LinearProgressIndicator(value: _stressProgress),
                    const SizedBox(height: 8),
                    Text(
                        'Emitting logs... ${(_stressProgress * 100).toStringAsFixed(0)}%'),
                  ] else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () => _runStressTest(50),
                          child: const Text('Emit 50 Logs'),
                        ),
                        ElevatedButton(
                          onPressed: () => _runStressTest(100),
                          child: const Text('Emit 100 Logs'),
                        ),
                        ElevatedButton(
                          onPressed: () => _runStressTest(500),
                          child: const Text('Emit 500 Logs'),
                        ),
                        ElevatedButton(
                          onPressed: () => _runStressTest(1000),
                          child: const Text('Emit 1000 Logs'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick Controls Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Logger Controls',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Flush Logger'),
                        onPressed: () async {
                          await widget.logger.flush();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Flushed logger transport')),
                            );
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.rotate_right),
                        label: const Text('Rotate Segment Now'),
                        onPressed: () async {
                          await widget.logger.storage.rotateSegment();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Segment rotated!')),
                            );
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.cleaning_services),
                        label: const Text('Purge Old Logs'),
                        onPressed: () async {
                          await widget.logger.storage.purgeOldLogs();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Purged old logs!')),
                            );
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Open Log Viewer Screen'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => FestenaoLogViewerScreen(
                                  storage: widget.logger.storage),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

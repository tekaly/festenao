import 'dart:async';
import 'log_level.dart';
import 'log_record.dart';
import 'storage/log_storage.dart';
import 'transport/log_transport.dart';

/// Main logging client interface for festenao_common.
class FestenaoLogger {
  final LogStorage storage;
  final LogTransport? transport;
  final String? deviceId;
  final String? sessionId;
  final String? loggerName;
  final LogLevel minLevel;

  final int batchSize;
  final Duration flushInterval;

  Timer? _flushTimer;
  bool _isFlushing = false;
  bool _closed = false;

  FestenaoLogger({
    required this.storage,
    this.transport,
    this.deviceId,
    this.sessionId,
    this.loggerName,
    this.minLevel = LogLevel.info,
    this.batchSize = 50,
    this.flushInterval = const Duration(seconds: 15),
  }) {
    if (transport != null && flushInterval > Duration.zero) {
      _flushTimer = Timer.periodic(flushInterval, (_) => flush());
    }
  }

  /// Appends a new log record to storage.
  void log({
    required LogLevel level,
    required String message,
    String? loggerName,
    Object? error,
    Object? stackTrace,
    Map<String, Object?>? extra,
  }) {
    if (_closed || level < minLevel) return;

    final record = LogRecord(
      level: level,
      loggerName: loggerName ?? this.loggerName,
      message: message,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
      extra: extra,
      deviceId: deviceId,
      sessionId: sessionId,
    );

    unawaited(storage.appendRecord(record));
  }

  void debug(
    String message, {
    Object? error,
    Object? stackTrace,
    Map<String, Object?>? extra,
  }) {
    log(
      level: LogLevel.debug,
      message: message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  void info(
    String message, {
    Object? error,
    Object? stackTrace,
    Map<String, Object?>? extra,
  }) {
    log(
      level: LogLevel.info,
      message: message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  void warning(
    String message, {
    Object? error,
    Object? stackTrace,
    Map<String, Object?>? extra,
  }) {
    log(
      level: LogLevel.warning,
      message: message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  void error(
    String message, {
    Object? error,
    Object? stackTrace,
    Map<String, Object?>? extra,
  }) {
    log(
      level: LogLevel.error,
      message: message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  void fatal(
    String message, {
    Object? error,
    Object? stackTrace,
    Map<String, Object?>? extra,
  }) {
    log(
      level: LogLevel.fatal,
      message: message,
      error: error,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Flushes unsent logs to transport and marks them as sent upon success.
  Future<void> flush() async {
    if (_closed || _isFlushing || transport == null) return;
    _isFlushing = true;
    try {
      final unsent = await storage.getUnsentRecords(limit: batchSize);
      if (unsent.isEmpty) return;

      final success = await transport!.sendBatch(unsent);
      if (success) {
        final ids = unsent.map((r) => r.id).toList();
        await storage.markAsSent(ids);
      }
    } catch (_) {
      // Ignore background flush failures
    } finally {
      _isFlushing = false;
    }
  }

  /// Closes logger resources after flushing.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _flushTimer?.cancel();
    await flush();
    await storage.close();
    await transport?.close();
  }
}

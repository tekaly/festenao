import 'dart:async';
import 'log_level.dart';
import 'log_record.dart';
import 'storage/log_storage.dart';
import 'storage/log_storage_prv.dart';
import 'transport/log_transport.dart';

/// Main logging client interface for festenao_common.
class FestenaoLogger {
  /// Storage backend for log records.
  final LogStorage storage;

  /// Optional transport for remote log submission.
  final LogTransport? transport;

  /// Device identifier.
  final String? deviceId;

  /// Session identifier.
  final String? sessionId;

  /// Name of this logger instance.
  final String? loggerName;

  /// Minimum log level to record.
  final LogLevel minLevel;

  /// Maximum batch size when flushing.
  final int batchSize;

  /// Frequency of automatic flushing.
  final Duration flushInterval;

  Timer? _flushTimer;
  bool _closed = false;
  Future<void>? _flushFuture;
  final _pendingAppends = LogPendingOperations();

  /// Creates a new [FestenaoLogger] instance.
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

    // Not awaited (an error stays uncaught as before), waited for by close.
    unawaited(_pendingAppends.track(storage.appendRecord(record)));
  }

  /// Logs a message at [LogLevel.debug].
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

  /// Logs a message at [LogLevel.info].
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

  /// Logs a message at [LogLevel.warning].
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

  /// Logs a message at [LogLevel.error].
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

  /// Logs a message at [LogLevel.fatal].
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
  ///
  /// While a flush runs, a new call waits for it.
  Future<void> flush() async {
    if (_closed) return;
    await _flush();
  }

  /// The running flush or a new one, even once closed (the last flush of
  /// [close]).
  Future<void> _flush() {
    if (transport == null) {
      return Future<void>.value();
    }
    // Kept only while pending.
    return _flushFuture ??= _doFlush().whenComplete(() {
      _flushFuture = null;
    });
  }

  Future<void> _doFlush() async {
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
    }
  }

  /// Closes logger resources after flushing.
  ///
  /// Waits for the pending appends and the running flush, then flushes the
  /// unsent records once more before closing the storage.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _flushTimer?.cancel();
    await _pendingAppends.wait();
    await _flushFuture;
    await _flush();
    await storage.close();
    await transport?.close();
  }
}

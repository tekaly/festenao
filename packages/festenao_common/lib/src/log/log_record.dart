import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'log_level.dart';

/// Maximum size allowed per record in bytes when serialized (256 KB).
const int maxLogRecordSizeBytes = 256 * 1024;

/// A single log entry stored and transmitted by festenao_log.
class LogRecord {
  /// Unique local identifier.
  final String id;

  /// Timestamp when the log entry was created (UTC).
  final DateTime timestamp;

  /// Severity level of the log entry.
  final LogLevel level;

  /// Optional hierarchical logger name.
  final String? loggerName;

  /// Main message content.
  final String message;

  /// Optional error message or stringified exception.
  final String? error;

  /// Optional stack trace string.
  final String? stackTrace;

  /// Arbitrary structured key-value metadata.
  final Map<String, Object?>? extra;

  /// Identifier of the kiosk or terminal emitting the log.
  final String? deviceId;

  /// Session identifier.
  final String? sessionId;

  /// Delivery status indicating whether this record was successfully pushed.
  final bool sent;

  /// Timestamp when this record was acknowledged by the remote receiver.
  final DateTime? sentAt;

  /// Creates a new log record.
  LogRecord({
    String? id,
    DateTime? timestamp,
    required this.level,
    this.loggerName,
    required String message,
    this.error,
    this.stackTrace,
    this.extra,
    this.deviceId,
    this.sessionId,
    this.sent = false,
    this.sentAt,
  }) : id = id ?? const Uuid().v4(),
       timestamp = (timestamp ?? DateTime.now()).toUtc(),
       message = _truncateIfNeeded(message, maxLogRecordSizeBytes);

  /// Truncate large string payloads if total record size exceeds 256KB.
  static String _truncateIfNeeded(String input, int maxLen) {
    if (input.length <= maxLen) return input;
    return '${input.substring(0, maxLen - 64)}...[truncated]';
  }

  /// Creates a copy of this record with updated fields.
  LogRecord copyWith({
    String? id,
    DateTime? timestamp,
    LogLevel? level,
    String? loggerName,
    String? message,
    String? error,
    String? stackTrace,
    Map<String, Object?>? extra,
    String? deviceId,
    String? sessionId,
    bool? sent,
    DateTime? sentAt,
  }) {
    return LogRecord(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      level: level ?? this.level,
      loggerName: loggerName ?? this.loggerName,
      message: message ?? this.message,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      extra: extra ?? this.extra,
      deviceId: deviceId ?? this.deviceId,
      sessionId: sessionId ?? this.sessionId,
      sent: sent ?? this.sent,
      sentAt: sentAt ?? this.sentAt,
    );
  }

  /// Converts record to JSON-encodable map.
  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'level': level.value,
      'levelName': level.name,
      if (loggerName != null) 'loggerName': loggerName,
      'message': message,
      if (error != null) 'error': error,
      if (stackTrace != null) 'stackTrace': stackTrace,
      if (extra != null && extra!.isNotEmpty) 'extra': extra,
      if (deviceId != null) 'deviceId': deviceId,
      if (sessionId != null) 'sessionId': sessionId,
      'sent': sent,
      if (sentAt != null) 'sentAt': sentAt!.toIso8601String(),
    };

    // Verify raw size limit (256 KB)
    final encodedLength = utf8.encode(jsonEncode(map)).length;
    if (encodedLength > maxLogRecordSizeBytes) {
      // Over budget: truncate stackTrace or message
      final excess = encodedLength - maxLogRecordSizeBytes;
      if (map['stackTrace'] is String) {
        final st = map['stackTrace'] as String;
        if (st.length > excess + 100) {
          map['stackTrace'] =
              '${st.substring(0, st.length - excess - 100)}...[truncated]';
        } else {
          map.remove('stackTrace');
        }
      } else if (map['message'] is String) {
        final msg = map['message'] as String;
        if (msg.length > excess + 100) {
          map['message'] =
              '${msg.substring(0, msg.length - excess - 100)}...[truncated]';
        }
      }
    }

    return map;
  }

  /// Creates a [LogRecord] from a serialized map.
  factory LogRecord.fromMap(Map<String, Object?> map) {
    final rawLevel = map['level'];
    final level = LogLevel.parse(rawLevel);

    final rawTs = map['timestamp'];
    final timestamp = rawTs is String
        ? DateTime.parse(rawTs).toUtc()
        : DateTime.now().toUtc();

    final rawSentAt = map['sentAt'];
    final sentAt = rawSentAt is String
        ? DateTime.parse(rawSentAt).toUtc()
        : null;

    Map<String, Object?>? extra;
    final rawExtra = map['extra'];
    if (rawExtra is Map) {
      extra = Map<String, Object?>.from(rawExtra);
    }

    return LogRecord(
      id: map['id']?.toString(),
      timestamp: timestamp,
      level: level,
      loggerName: map['loggerName']?.toString(),
      message: map['message']?.toString() ?? '',
      error: map['error']?.toString(),
      stackTrace: map['stackTrace']?.toString(),
      extra: extra,
      deviceId: map['deviceId']?.toString(),
      sessionId: map['sessionId']?.toString(),
      sent: (map['sent'] as bool?) ?? false,
      sentAt: sentAt,
    );
  }

  @override
  String toString() {
    return 'LogRecord(id: $id, ts: ${timestamp.toIso8601String()}, level: ${level.name}, logger: $loggerName, message: "$message", sent: $sent)';
  }
}

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

    // Size limit (256 KB) of the encoded record, in UTF-8 bytes: the error,
    // then the stack trace, then the message are cut.
    var excess = _encodedSize(map) - maxLogRecordSizeBytes;
    for (final key in const ['error', 'stackTrace', 'message']) {
      if (excess <= 0) {
        break;
      }
      final value = map[key];
      if (value is! String) {
        continue;
      }
      var keepBytes = utf8.encode(value).length;
      while (excess > 0 && keepBytes > 0) {
        keepBytes -= excess + _truncatedSuffix.length;
        if (keepBytes < 0) {
          keepBytes = 0;
        }
        map[key] = keepBytes == 0
            ? _truncatedSuffix
            : '${_utf8Prefix(value, keepBytes)}$_truncatedSuffix';
        excess = _encodedSize(map) - maxLogRecordSizeBytes;
      }
    }

    return map;
  }

  static const _truncatedSuffix = '...[truncated]';

  static int _encodedSize(Map<String, Object?> map) =>
      utf8.encode(jsonEncode(map)).length;

  /// The longest prefix of [input] whose UTF-8 encoding fits in [maxBytes],
  /// a surrogate pair never split.
  static String _utf8Prefix(String input, int maxBytes) {
    var bytes = 0;
    var index = 0;
    while (index < input.length) {
      final unit = input.codeUnitAt(index);
      var units = 1;
      int unitBytes;
      if (unit < 0x80) {
        unitBytes = 1;
      } else if (unit < 0x800) {
        unitBytes = 2;
      } else if ((unit & 0xFC00) == 0xD800 &&
          index + 1 < input.length &&
          (input.codeUnitAt(index + 1) & 0xFC00) == 0xDC00) {
        unitBytes = 4;
        units = 2;
      } else {
        unitBytes = 3;
      }
      if (bytes + unitBytes > maxBytes) {
        break;
      }
      bytes += unitBytes;
      index += units;
    }
    return input.substring(0, index);
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

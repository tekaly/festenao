import '../log_level.dart';
import '../log_record.dart';

/// Filtering parameters when querying log records.
class LogQueryFilter {
  /// Match records created on or after this timestamp.
  final DateTime? fromDateTime;

  /// Match records created on or before this timestamp.
  final DateTime? toDateTime;

  /// Minimum severity level required (inclusive).
  final LogLevel? minLevel;

  /// Specific set of allowed severity levels.
  final Set<LogLevel>? levels;

  /// Filter by device identifier.
  final String? deviceId;

  /// Filter by session identifier.
  final String? sessionId;

  /// Filter by hierarchical logger name.
  final String? loggerName;

  /// Delivery status filter: `true` for sent logs only, `false` for unsent logs only, `null` for all.
  final bool? sentOnly;

  /// Text search query matching message, logger name, error, or extra fields (case-insensitive).
  final String? searchQuery;

  const LogQueryFilter({
    this.fromDateTime,
    this.toDateTime,
    this.minLevel,
    this.levels,
    this.deviceId,
    this.sessionId,
    this.loggerName,
    this.sentOnly,
    this.searchQuery,
  });

  /// Convenience constructor for unsent records only.
  factory LogQueryFilter.unsent({
    DateTime? fromDateTime,
    DateTime? toDateTime,
    LogLevel? minLevel,
    String? deviceId,
  }) {
    return LogQueryFilter(
      fromDateTime: fromDateTime,
      toDateTime: toDateTime,
      minLevel: minLevel,
      deviceId: deviceId,
      sentOnly: false,
    );
  }

  /// Tests whether a given [LogRecord] matches all criteria of this filter.
  bool matches(LogRecord record) {
    if (fromDateTime != null && record.timestamp.isBefore(fromDateTime!)) {
      return false;
    }
    if (toDateTime != null && record.timestamp.isAfter(toDateTime!)) {
      return false;
    }
    if (minLevel != null && record.level < minLevel!) {
      return false;
    }
    if (levels != null && levels!.isNotEmpty && !levels!.contains(record.level)) {
      return false;
    }
    if (deviceId != null && record.deviceId != deviceId) {
      return false;
    }
    if (sessionId != null && record.sessionId != sessionId) {
      return false;
    }
    if (loggerName != null && record.loggerName != loggerName) {
      return false;
    }
    if (sentOnly != null && record.sent != sentOnly) {
      return false;
    }
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final q = searchQuery!.toLowerCase();
      final msgMatch = record.message.toLowerCase().contains(q);
      final loggerMatch = record.loggerName?.toLowerCase().contains(q) ?? false;
      final errorMatch = record.error?.toLowerCase().contains(q) ?? false;
      final extraMatch = record.extra?.values
              .whereType<String>()
              .any((val) => val.toLowerCase().contains(q)) ??
          false;
      if (!msgMatch && !loggerMatch && !errorMatch && !extraMatch) {
        return false;
      }
    }
    return true;
  }
}

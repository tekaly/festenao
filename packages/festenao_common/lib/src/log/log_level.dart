/// Severity level for log records.
class LogLevel implements Comparable<LogLevel> {
  /// Numeric value of the level.
  final int value;

  /// Name of the level.
  final String name;

  /// Creates a log level with numeric [value] and [name].
  const LogLevel(this.value, this.name);

  /// All log messages level.
  static const LogLevel all = LogLevel(0, 'ALL');

  /// Debug log level.
  static const LogLevel debug = LogLevel(300, 'DEBUG');

  /// Info log level.
  static const LogLevel info = LogLevel(500, 'INFO');

  /// Warning log level.
  static const LogLevel warning = LogLevel(800, 'WARNING');

  /// Error log level.
  static const LogLevel error = LogLevel(900, 'ERROR');

  /// Fatal log level.
  static const LogLevel fatal = LogLevel(1000, 'FATAL');

  /// Off level (disables logging).
  static const LogLevel off = LogLevel(2000, 'OFF');

  /// List of standard log levels.
  static const List<LogLevel> values = [
    all,
    debug,
    info,
    warning,
    error,
    fatal,
    off,
  ];

  @override
  int compareTo(LogLevel other) => value.compareTo(other.value);

  /// Returns true if this level is greater than or equal to [other].
  bool operator >=(LogLevel other) => value >= other.value;

  /// Returns true if this level is less than or equal to [other].
  bool operator <=(LogLevel other) => value <= other.value;

  /// Returns true if this level is strictly greater than [other].
  bool operator >(LogLevel other) => value > other.value;

  /// Returns true if this level is strictly less than [other].
  bool operator <(LogLevel other) => value < other.value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogLevel &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => name;

  /// Parse string or int into a [LogLevel]. Defaults to [info] if unrecognized.
  factory LogLevel.parse(dynamic input) {
    if (input is LogLevel) return input;
    if (input is int) {
      for (final level in values) {
        if (level.value == input) return level;
      }
      return LogLevel(input, 'CUSTOM($input)');
    }
    if (input is String) {
      final upper = input.toUpperCase().trim();
      for (final level in values) {
        if (level.name == upper) return level;
      }
      final parsedInt = int.tryParse(input);
      if (parsedInt != null) return LogLevel.parse(parsedInt);
    }
    return info;
  }
}

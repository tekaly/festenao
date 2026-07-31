/// Severity level for log records.
class LogLevel implements Comparable<LogLevel> {
  /// Numeric value of the level.
  final int value;

  /// Name of the level.
  final String name;

  const LogLevel(this.value, this.name);

  static const LogLevel all = LogLevel(0, 'ALL');
  static const LogLevel debug = LogLevel(300, 'DEBUG');
  static const LogLevel info = LogLevel(500, 'INFO');
  static const LogLevel warning = LogLevel(800, 'WARNING');
  static const LogLevel error = LogLevel(900, 'ERROR');
  static const LogLevel fatal = LogLevel(1000, 'FATAL');
  static const LogLevel off = LogLevel(2000, 'OFF');

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

  bool operator >=(LogLevel other) => value >= other.value;
  bool operator <=(LogLevel other) => value <= other.value;
  bool operator >(LogLevel other) => value > other.value;
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

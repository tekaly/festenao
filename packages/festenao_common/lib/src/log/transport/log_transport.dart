import '../log_record.dart';

/// Transport mechanism for pushing log records to a remote receiver endpoint.
abstract class LogTransport {
  /// Sends a batch of log records to the remote endpoint.
  /// Returns `true` if successfully acknowledged by the server, `false` otherwise.
  Future<bool> sendBatch(List<LogRecord> records);

  /// Close any underlying network connection resources.
  Future<void> close();
}

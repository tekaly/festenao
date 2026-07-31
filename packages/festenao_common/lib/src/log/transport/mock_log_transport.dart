import '../log_record.dart';
import 'log_transport.dart';

/// Mock transport implementation for unit testing and offline simulation.
class MockLogTransport implements LogTransport {
  final List<List<LogRecord>> sentBatches = [];
  bool shouldSucceed = true;

  @override
  Future<bool> sendBatch(List<LogRecord> records) async {
    if (records.isEmpty) return true;
    if (shouldSucceed) {
      sentBatches.add(List.from(records));
      return true;
    }
    return false;
  }

  @override
  Future<void> close() async {}
}

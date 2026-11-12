import 'package:festenao_common_flutter/log/log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps [count] steps of [step].
Future<void> _pumpFor(
  WidgetTester tester, {
  int count = 100,
  Duration step = const Duration(milliseconds: 20),
}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(step);
  }
}

Future<void> _openPlayground(WidgetTester tester, FestenaoLogger logger) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: FestenaoLogScreen(logger: logger)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.text('Log Playground'));
  await tester.pumpAndSettle();
}

Future<void> _tapButton(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
}

void main() {
  testWidgets('leaving the playground tab during a stress test', (
    tester,
  ) async {
    var logger = FestenaoLogger(storage: MemoryLogStorage());
    await _openPlayground(tester, logger);
    await _tapButton(tester, 'Emit 1000 Logs');
    await tester.pump(const Duration(milliseconds: 15));
    await tester.pump(const Duration(milliseconds: 15));
    // Back to the explorer while it runs: the playground is disposed.
    await tester.tap(find.text('Log Explorer'));
    await _pumpFor(tester);
    expect(tester.takeException(), isNull);
    await logger.close();
  }, timeout: const Timeout(Duration(minutes: 1)));

  testWidgets('the emitted count after a stress test', (tester) async {
    var logger = FestenaoLogger(storage: MemoryLogStorage());
    await _openPlayground(tester, logger);
    await _tapButton(tester, 'Emit 50 Logs');
    await _pumpFor(tester);
    // The snack bar of the stress test gone.
    await _pumpFor(tester, count: 60, step: const Duration(milliseconds: 100));
    await _tapButton(tester, 'Emit Single Log Record');
    await _pumpFor(tester, count: 3, step: const Duration(milliseconds: 100));
    expect(find.text('Emitted INFO log #51'), findsOneWidget);
    await logger.close();
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('the global logger keeps the debug logs', () async {
    var logger = globalFestenaoLogger;
    expect(logger.minLevel, LogLevel.debug);
    logger.log(level: LogLevel.debug, message: 'a debug log');
    var reader = FestenaoLogReader(storage: logger.storage);
    var records = <LogRecord>[];
    for (var i = 0; i < 50 && records.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      records = await reader.queryLogs(
        const LogQueryFilter(searchQuery: 'a debug log'),
      );
    }
    expect(records.map((record) => record.level), [LogLevel.debug]);
  }, timeout: const Timeout(Duration(seconds: 30)));
}

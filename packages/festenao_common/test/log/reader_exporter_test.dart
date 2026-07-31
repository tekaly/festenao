import 'dart:convert';
import 'package:dev_test/test.dart';
import 'package:festenao_common/log/log.dart';
import 'package:festenao_common/log/log_server.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tekartik_http/http_memory.dart';

void main() {
  group('FestenaoLogReader & FestenaoLogExporter', () {
    late MemoryLogStorage storage;
    late FestenaoLogReader reader;
    late FestenaoLogExporter exporter;

    setUp(() async {
      storage = MemoryLogStorage();
      await storage.init();

      await storage.appendRecord(
        LogRecord(
          level: LogLevel.info,
          message: 'System boot success',
          loggerName: 'sys.boot',
          deviceId: 'kiosk-1',
        ),
      );
      await storage.appendRecord(
        LogRecord(
          level: LogLevel.warning,
          message: 'Network lag detected',
          loggerName: 'sys.net',
          deviceId: 'kiosk-1',
        ),
      );
      await storage.appendRecord(
        LogRecord(
          level: LogLevel.error,
          message: 'Payment gateway timeout',
          loggerName: 'pay.gateway',
          deviceId: 'kiosk-2',
        ),
      );

      reader = FestenaoLogReader(storage: storage);
      exporter = FestenaoLogExporter(reader: reader);
    });

    tearDown(() async {
      await storage.close();
    });

    test('reader query & stream', () async {
      final all = await reader.queryLogs(const LogQueryFilter());
      expect(all.length, 3);

      final kiosk1Only = await reader.queryLogs(
        const LogQueryFilter(deviceId: 'kiosk-1'),
      );
      expect(kiosk1Only.length, 2);

      final searchNet = await reader.queryLogs(
        const LogQueryFilter(searchQuery: 'gateway'),
      );
      expect(searchNet.length, 1);
      expect(searchNet.first.loggerName, 'pay.gateway');

      final summaries = await reader.getSegmentSummaries();
      expect(summaries.isNotEmpty, isTrue);
    });

    test('exporter formats JSON, JSONL, CSV', () async {
      final jsonStr = await exporter.exportLogsToString(
        const LogQueryFilter(),
        format: ExportFormat.json,
      );
      expect(jsonStr, contains('Payment gateway timeout'));

      final jsonlStr = await exporter.exportLogsToString(
        const LogQueryFilter(),
        format: ExportFormat.jsonl,
      );
      final lines = jsonlStr.trim().split('\n');
      expect(lines.length, 3);

      final csvStr = await exporter.exportLogsToString(
        const LogQueryFilter(),
        format: ExportFormat.csv,
      );
      expect(
        csvStr,
        contains('id,timestamp,level,loggerName,message,deviceId,sent'),
      );
      expect(csvStr, contains('Payment gateway timeout'));
    });

    test('exporter exportLogsToFile with fs_shim memory', () async {
      final fs = newFileSystemMemory();
      final result = await exporter.exportLogsToFile(
        const LogQueryFilter(),
        '/exports/logs.json',
        format: ExportFormat.json,
        fileSystem: fs,
      );

      expect(result.recordCount, 3);
      expect(result.sizeBytes, greaterThan(0));

      final file = fs.file('/exports/logs.json');
      expect(await file.exists(), isTrue);
      final content = await file.readAsString();
      expect(content, contains('System boot success'));
    });

    test(
      'exporter sendLogsToEndpoint using memory HTTP server/client',
      () async {
        final httpFactory = httpServerFactoryMemory;
        final clientFactory = httpClientFactoryMemory;

        // Spin up in-memory HTTP server receiver
        final server = await httpFactory.bind('localhost', 0);
        server.listen((request) async {
          final body = await utf8.decoder.bind(request).join();
          final handler = FestenaoLogServerHandler(storage: MemoryLogStorage());
          final res = await handler.handleJsonPayload(body);
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.parse(
            'application/json',
          );
          request.response.write(jsonEncode(res));
          await request.response.close();
        });

        final url = Uri.parse('http://localhost:${server.port}/logs');
        final client = clientFactory.newClient();

        final sendResult = await exporter.sendLogsToEndpoint(
          const LogQueryFilter(),
          url,
          format: ExportFormat.json,
          client: client,
        );

        expect(sendResult.success, isTrue);
        expect(sendResult.statusCode, 200);
        expect(sendResult.recordCount, 3);

        await server.close();
      },
    );
  });
}

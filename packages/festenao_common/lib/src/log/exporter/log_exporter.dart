import 'dart:convert';
import 'package:fs_shim/fs.dart';
import 'package:tekartik_http/http.dart';
import '../log_record.dart';
import '../reader/log_query_filter.dart';
import '../reader/log_reader.dart';
import 'export_format.dart';

/// Result of an export operation.
class ExportResult {
  /// Total number of records exported.
  final int recordCount;

  /// Total size of exported data in bytes.
  final int sizeBytes;

  /// Path or content of exported logs.
  final String pathOrContent;

  /// Creates an export result.
  ExportResult({
    required this.recordCount,
    required this.sizeBytes,
    required this.pathOrContent,
  });
}

/// Result of an export-and-send operation.
class SendLogsResult {
  /// Whether the send operation succeeded.
  final bool success;

  /// HTTP status code returned by the server.
  final int statusCode;

  /// Number of records sent.
  final int recordCount;

  /// HTTP response body returned by the server.
  final String? responseBody;

  /// Creates a send logs result.
  SendLogsResult({
    required this.success,
    required this.statusCode,
    required this.recordCount,
    this.responseBody,
  });
}

/// Log exporter utility for formatting and transmitting log batches.
class FestenaoLogExporter {
  /// The log reader used for querying.
  final FestenaoLogReader reader;

  /// Creates a log exporter.
  FestenaoLogExporter({required this.reader});

  /// Serializes logs matching [filter] into a string formatted as [format].
  Future<String> exportLogsToString(
    LogQueryFilter filter, {
    ExportFormat format = ExportFormat.json,
  }) async {
    final records = await reader.queryLogs(filter, descending: false);
    return formatRecords(records, format);
  }

  /// Formats a list of [LogRecord] into string based on [ExportFormat].
  static String formatRecords(List<LogRecord> records, ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        final maps = records.map((r) => r.toMap()).toList();
        return const JsonEncoder.withIndent('  ').convert(maps);
      case ExportFormat.jsonl:
        return records.map((r) => jsonEncode(r.toMap())).join('\n');
      case ExportFormat.csv:
        final buffer = StringBuffer();
        buffer.writeln('id,timestamp,level,loggerName,message,deviceId,sent');
        for (final r in records) {
          final msgEscaped = r.message.replaceAll('"', '""');
          final loggerEscaped = (r.loggerName ?? '').replaceAll('"', '""');
          buffer.writeln(
            '"${r.id}","${r.timestamp.toIso8601String()}","${r.level.name}","$loggerEscaped","$msgEscaped","${r.deviceId ?? ""}","${r.sent}"',
          );
        }
        return buffer.toString();
    }
  }

  /// Exports logs matching [filter] to a target file on [fileSystem].
  Future<ExportResult> exportLogsToFile(
    LogQueryFilter filter,
    String targetPath, {
    ExportFormat format = ExportFormat.json,
    FileSystem? fileSystem,
  }) async {
    final content = await exportLogsToString(filter, format: format);
    final count = (await reader.queryLogs(filter)).length;

    if (fileSystem != null) {
      final file = fileSystem.file(targetPath);
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      await file.writeAsString(content);
    }
    final bytes = utf8.encode(content).length;

    return ExportResult(
      recordCount: count,
      sizeBytes: bytes,
      pathOrContent: targetPath,
    );
  }

  /// Queries logs matching [filter], serializes them in [format], and POSTs them to [destinationUrl].
  Future<SendLogsResult> sendLogsToEndpoint(
    LogQueryFilter filter,
    Uri destinationUrl, {
    Map<String, String>? headers,
    ExportFormat format = ExportFormat.json,
    Client? client,
  }) async {
    final records = await reader.queryLogs(filter);
    if (records.isEmpty) {
      return SendLogsResult(
        success: true,
        statusCode: 200,
        recordCount: 0,
        responseBody: 'No records to send',
      );
    }

    final content = formatRecords(records, format);
    final httpClient = client ?? Client();

    String contentType;
    switch (format) {
      case ExportFormat.json:
        contentType = 'application/json; charset=utf-8';
        break;
      case ExportFormat.jsonl:
        contentType = 'application/x-ndjson; charset=utf-8';
        break;
      case ExportFormat.csv:
        contentType = 'text/csv; charset=utf-8';
        break;
    }

    final reqHeaders = <String, String>{
      'Content-Type': contentType,
      ...?headers,
    };

    try {
      final response = await httpClient.post(
        destinationUrl,
        headers: reqHeaders,
        body: content,
      );

      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

      return SendLogsResult(
        success: isSuccess,
        statusCode: response.statusCode,
        recordCount: records.length,
        responseBody: response.body,
      );
    } catch (e) {
      return SendLogsResult(
        success: false,
        statusCode: 500,
        recordCount: records.length,
        responseBody: e.toString(),
      );
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }
}

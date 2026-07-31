import 'dart:convert';
import 'package:tekartik_http/http.dart';
import '../log_record.dart';
import 'log_transport.dart';

/// HTTP transport pushing log record batches to a remote server.
class HttpLogTransport implements LogTransport {
  /// Remote HTTP endpoint.
  final Uri endpoint;

  /// HTTP client instance.
  final Client client;

  /// Optional HTTP headers.
  final Map<String, String>? headers;

  /// Creates an [HttpLogTransport] instance.
  HttpLogTransport({required this.endpoint, Client? client, this.headers})
    : client = client ?? Client();

  @override
  Future<bool> sendBatch(List<LogRecord> records) async {
    if (records.isEmpty) return true;
    try {
      final body = jsonEncode(records.map((r) => r.toMap()).toList());
      final reqHeaders = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
        ...?headers,
      };

      final response = await client.post(
        endpoint,
        headers: reqHeaders,
        body: body,
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() async {
    client.close();
  }
}

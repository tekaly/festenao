import 'dart:convert';
import 'package:tekartik_http/http.dart';
import '../log_record.dart';
import 'log_transport.dart';

/// HTTP transport pushing log record batches to a remote server.
class HttpLogTransport implements LogTransport {
  final Uri endpoint;
  final Client client;
  final Map<String, String>? headers;

  HttpLogTransport({
    required this.endpoint,
    Client? client,
    this.headers,
  }) : client = client ?? Client();

  @override
  Future<bool> sendBatch(List<LogRecord> records) async {
    if (records.isEmpty) return true;
    try {
      final body = jsonEncode(records.map((r) => r.toMap()).toList());
      final reqHeaders = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
        if (headers != null) ...headers!,
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

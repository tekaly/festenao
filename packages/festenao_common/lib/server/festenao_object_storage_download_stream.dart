/// The download url of an object storage file served by the api itself:
/// `GET <command>/gdrive/stream?token=<token>`, with `Range` support.
///
/// A browser cannot fetch drive's `webContentLink` (no cors there), while
/// the command function serves the content with cors on, for every client
/// alike. So `gdrive/getDownloadUrl` answers this url
/// (`FestenaoObjectStorageHandlerOptions.downloadStream`) and the https
/// function serves it before the json commands
/// ([FestenaoObjectStorageDownloadStream.onDownloadStreamOrNull]).
///
/// The token names the file and expires: aes encrypted with a key of the
/// server, a client can neither forge one nor change the file or the expiry
/// of one it was given. Transport agnostic: an express request
/// ([FestenaoObjectStorageDownloadStream.sendDownloadStream]) or an admin
/// sdk request (the app sends the [DownloadStreamResponse] itself).
library;

import 'dart:convert';
import 'dart:math';

import 'package:festenao_common/data/object_storage.dart';
import 'package:tekartik_app_crypto/encrypt.dart';
import 'package:tekartik_app_crypto/hash.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// The length of a download token key, what [aesEncrypt] takes.
const downloadTokenKeyLength = 32;

/// A key derived from a secret the server has anyway (the private key of
/// its service account): the same on every instance of the function, and
/// nowhere in the source.
String downloadTokenKeyFromSecret(String secret) => md5Hash(secret);

/// A random key, for a server of one process (local, tests): its urls do
/// not survive a restart.
String randomDownloadTokenKey() {
  var random = Random.secure();
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return String.fromCharCodes(
    List.generate(
      downloadTokenKeyLength,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ),
  );
}

/// How long a download url stays valid.
const downloadTokenLifetime = Duration(hours: 1);

/// The path of the stream endpoint below the command function.
const downloadStreamPathSegments = ['gdrive', 'stream'];

/// The query parameter holding the token.
const downloadStreamTokenParam = 'token';

/// What a download url grants: one file, until [expires].
class DownloadToken {
  /// The file (its object storage path, a drive id).
  final String path;

  /// Not valid past this instant.
  final DateTime expires;

  /// A token for [path], valid [downloadTokenLifetime] from now by default.
  DownloadToken({required this.path, DateTime? expires})
    : expires = expires ?? DateTime.timestamp().add(downloadTokenLifetime);

  /// True once past [expires].
  bool get isExpired => DateTime.timestamp().isAfter(expires);

  /// The encrypted form with [key] ([downloadTokenKeyLength] ascii
  /// characters; base 64 text, the query encoding of the url takes care of
  /// its `+`, `/` and `=`).
  String encode(String key) => aesEncrypt(
    jsonEncode({'p': path, 'e': expires.toUtc().toIso8601String()}),
    key,
  );

  /// Back from [encode], null for anything that is not a valid token.
  static DownloadToken? tryDecode(String? token, String key) {
    if (token == null) {
      return null;
    }
    try {
      var map = jsonDecode(aesDecrypt(token, key)) as Map;
      return DownloadToken(
        path: map['p'] as String,
        expires: DateTime.parse(map['e'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/// The response of the stream endpoint, whatever the transport sends it.
class DownloadStreamResponse {
  /// Http status.
  final int statusCode;

  /// Headers (content type, length, range).
  final Map<String, String> headers;

  /// The content, null for an error ([message] then).
  final Stream<Uint8List>? body;

  /// The error text.
  final String? message;

  /// A content response.
  DownloadStreamResponse.content({
    required this.statusCode,
    required this.headers,
    required Stream<Uint8List> this.body,
  }) : message = null;

  /// An error response.
  DownloadStreamResponse.error(this.statusCode, String this.message)
    : headers = const {'content-type': 'text/plain'},
      body = null;
}

/// A `Range` header (`bytes=start-end`, `bytes=start-`, `bytes=-suffix`)
/// resolved against [total] (when known): the first byte and the count, or
/// null when there is no range to honor.
({int start, int? size})? parseRangeHeader(String? range, {int? total}) {
  if (range == null) {
    return null;
  }
  var match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range.trim());
  if (match == null) {
    return null;
  }
  var startText = match.group(1)!;
  var endText = match.group(2)!;
  if (startText.isEmpty) {
    // The last `suffix` bytes, only possible knowing the total.
    var suffix = int.tryParse(endText);
    if (suffix == null || total == null || suffix <= 0) {
      return null;
    }
    var start = total - suffix;
    return (start: start < 0 ? 0 : start, size: start < 0 ? total : suffix);
  }
  var start = int.parse(startText);
  if (endText.isEmpty) {
    return (start: start, size: total == null ? null : total - start);
  }
  var end = int.parse(endText);
  if (end < start) {
    return null;
  }
  if (total != null && end >= total) {
    // Past the end: the remainder of the file, not more bytes than it has
    // (RFC 9110 14.1.2).
    end = total - 1;
  }
  return (start: start, size: end - start + 1);
}

/// True when [uri] is the stream endpoint (`…/gdrive/stream`), whatever
/// precedes it (the function name, or nothing once stripped): what a server
/// with no storage still recognizes, to refuse it rather than parse it as a
/// json command.
bool isObjectStorageDownloadStreamUri(Uri uri) {
  var segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  var n = downloadStreamPathSegments.length;
  if (segments.length < n) {
    return false;
  }
  for (var i = 0; i < n; i++) {
    if (segments[segments.length - n + i] != downloadStreamPathSegments[i]) {
      return false;
    }
  }
  return true;
}

/// The download urls of [objectStorage] and the stream endpoint behind
/// them, on the command function at [commandUri].
class FestenaoObjectStorageDownloadStream {
  /// The storage the files are read from.
  final ObjectStorage objectStorage;

  /// The key of the tokens ([downloadTokenKeyLength] characters): the same
  /// on every instance of the deployed function
  /// ([downloadTokenKeyFromSecret]), random by default (one process).
  final String key;

  final Uri Function() _commandUri;

  /// The absolute url of the command function, what the download urls are
  /// built on (read at each url: a local server sets its own once
  /// started).
  Uri get commandUri => _commandUri();

  /// The stream of [objectStorage] on the command function at [commandUri].
  FestenaoObjectStorageDownloadStream({
    required this.objectStorage,
    required this._commandUri,
    String? key,
  }) : key = key ?? randomDownloadTokenKey() {
    assert(this.key.length == downloadTokenKeyLength);
  }

  /// The download url of [path]: the stream endpoint with a fresh token.
  Uri downloadUrl(String path) => commandUri.replace(
    pathSegments: [...commandUri.pathSegments, ...downloadStreamPathSegments],
    queryParameters: {
      downloadStreamTokenParam: DownloadToken(path: path).encode(key),
    },
  );

  /// True when [uri] is the stream endpoint, whatever precedes it (the
  /// function name, or nothing once stripped).
  bool isDownloadStreamUri(Uri uri) => isObjectStorageDownloadStreamUri(uri);

  /// The stream endpoint, transport agnostic: null when [uri] is not it,
  /// the response to send otherwise — the content of the file the token
  /// names (a part of it on a `Range`), or an error.
  Future<DownloadStreamResponse?> onDownloadStreamOrNull({
    required String method,
    required Uri uri,
    String? range,
  }) async {
    if (!isDownloadStreamUri(uri)) {
      return null;
    }
    if (method.toUpperCase() != 'GET') {
      return DownloadStreamResponse.error(405, 'GET only');
    }
    var token = DownloadToken.tryDecode(
      uri.queryParameters[downloadStreamTokenParam],
      key,
    );
    if (token == null) {
      return DownloadStreamResponse.error(403, 'Invalid token');
    }
    if (token.isExpired) {
      return DownloadStreamResponse.error(403, 'Expired token');
    }
    ObjectStorageMeta meta;
    try {
      meta = await objectStorage.getItem(token.path);
    } catch (e) {
      return DownloadStreamResponse.error(404, 'Not found: $e');
    }
    var total = meta.size;
    var headers = <String, String>{
      'content-type': meta.mimeType ?? 'application/octet-stream',
      'accept-ranges': 'bytes',
    };
    // Streamed from the meta path: the file itself, a shortcut's target.
    var part = parseRangeHeader(range, total: total);
    if (part == null) {
      if (total != null) {
        headers['content-length'] = '$total';
      }
      return DownloadStreamResponse.content(
        statusCode: 200,
        headers: headers,
        body: objectStorage.downloadStream(meta.path),
      );
    }
    if (total != null && part.start >= total) {
      return DownloadStreamResponse.error(416, 'Range not satisfiable');
    }
    var size = part.size;
    if (size != null) {
      headers['content-length'] = '$size';
    }
    var end = size == null ? '' : '${part.start + size - 1}';
    headers['content-range'] = 'bytes ${part.start}-$end/${total ?? '*'}';
    return DownloadStreamResponse.content(
      statusCode: 206,
      headers: headers,
      body: objectStorage.downloadStream(
        meta.path,
        start: part.start,
        size: size,
      ),
    );
  }

  /// Send [stream] on an express request (the memory, sim and node servers).
  Future<void> sendDownloadStream(
    ExpressHttpRequest request,
    DownloadStreamResponse stream,
  ) => sendObjectStorageDownloadStream(request, stream);
}

/// Send [stream] on an express request (the memory, sim and node servers):
/// its status, its headers, then its body or its error text.
Future<void> sendObjectStorageDownloadStream(
  ExpressHttpRequest request,
  DownloadStreamResponse stream,
) async {
  var response = request.response;
  response.statusCode = stream.statusCode;
  stream.headers.forEach(response.headers.set);
  var body = stream.body;
  if (body == null) {
    await response.send(stream.message);
    return;
  }
  try {
    await for (var chunk in body) {
      response.add(chunk);
    }
  } finally {
    await response.close();
  }
}

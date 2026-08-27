import 'dart:convert';

import 'package:http/http.dart' as http;

import 'yt_playlist_entry.dart';

/// A playlist as read off youtube's own playlist page.
class YoutubePlaylistListing {
  /// The videos, in the playlist's own order.
  final List<YtPlaylistEntry> entries;

  /// The playlist name, when the page carried one.
  final String? title;

  /// Constructor for [YoutubePlaylistListing].
  const YoutubePlaylistListing({required this.entries, this.title});
}

/// Reads the contents of a youtube playlist off the playlist page.
///
/// youtube_explode_dart cannot do this any more: youtube moved its playlist
/// page to `lockupViewModel` entries and the package's parser comes back with
/// nothing at all. Everything else it does (single videos, media urls) still
/// works, so this only covers the listing.
///
/// The page carries the first 100 entries inline; the rest come from the same
/// innertube continuation call the page itself would make while scrolling.
class YoutubePlaylistPage {
  /// Constructor for [YoutubePlaylistPage].
  YoutubePlaylistPage({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  /// Sent so youtube serves the page instead of redirecting to its consent
  /// wall, and so the strings come back in english.
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
    'Cookie': 'SOCS=CAI',
  };

  final http.Client _client;
  final bool _ownsClient;

  /// Fetches up to [max] entries of playlist [playlistId].
  Future<YoutubePlaylistListing> fetch(
    String playlistId, {
    int max = 200,
  }) async {
    final uri = Uri.https('www.youtube.com', '/playlist', {
      'list': playlistId,
      'hl': 'en',
    });
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Playlist page answered ${response.statusCode}',
        uri,
      );
    }

    final html = response.body;
    final data = _extractJson(html, 'ytInitialData');
    if (data == null) {
      return const YoutubePlaylistListing(entries: []);
    }

    final entries = <YtPlaylistEntry>[];
    final seen = <String>{};
    var continuation = _collect(data, entries, seen, max);

    final apiKey = _firstMatch(html, r'"INNERTUBE_API_KEY":"([^"]+)"');
    final clientVersion = _firstMatch(
      html,
      r'"INNERTUBE_CLIENT_VERSION":"([^"]+)"',
    );
    while (continuation != null &&
        entries.length < max &&
        apiKey != null &&
        clientVersion != null) {
      final page = await _continue(apiKey, clientVersion, continuation);
      if (page == null) break;
      final next = _collect(page, entries, seen, max);
      // Guard against a continuation that keeps handing back the same page.
      if (next == continuation) break;
      continuation = next;
    }

    return YoutubePlaylistListing(entries: entries, title: _titleOf(data));
  }

  Future<Map<String, dynamic>?> _continue(
    String apiKey,
    String clientVersion,
    String token,
  ) async {
    final uri = Uri.https('www.youtube.com', '/youtubei/v1/browse', {
      'key': apiKey,
      'prettyPrint': 'false',
    });
    final response = await _client.post(
      uri,
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'context': {
          'client': {
            'clientName': 'WEB',
            'clientVersion': clientVersion,
            'hl': 'en',
            'gl': 'US',
          },
        },
        'continuation': token,
      }),
    );
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Walks [data] for video entries, appending them to [entries], and returns
  /// the continuation token for the next page if there is one.
  String? _collect(
    Object? data,
    List<YtPlaylistEntry> entries,
    Set<String> seen,
    int max,
  ) {
    String? continuation;

    void visit(Object? node) {
      if (node is List) {
        for (final child in node) {
          visit(child);
        }
        return;
      }
      if (node is! Map) return;

      final lockup = node['lockupViewModel'];
      if (lockup is Map && lockup['contentType'] == _videoContentType) {
        final entry = _entryOf(lockup);
        if (entry != null && entries.length < max && seen.add(entry.videoId)) {
          entries.add(entry);
        }
      }
      // The page carries several continuation commands (and a couple of empty
      // ones); the first real token is the one that pages the video grid.
      final command = node['continuationCommand'];
      if (continuation == null && command is Map) {
        final token = command['token'];
        if (token is String && token.isNotEmpty) continuation = token;
      }
      for (final child in node.values) {
        visit(child);
      }
    }

    visit(data);
    return continuation;
  }

  static const _videoContentType = 'LOCKUP_CONTENT_TYPE_VIDEO';

  static YtPlaylistEntry? _entryOf(Map<Object?, Object?> lockup) {
    final videoId = lockup['contentId'];
    if (videoId is! String || videoId.isEmpty) return null;

    final metadata = _dig(lockup, ['metadata', 'lockupMetadataViewModel']);
    final title = _dig(metadata, ['title', 'content']);
    final author = _dig(metadata, [
      'metadata',
      'contentMetadataViewModel',
      'metadataRows',
      0,
      'metadataParts',
      0,
      'text',
      'content',
    ]);

    return YtPlaylistEntry(
      videoId: videoId,
      title: title is String && title.isNotEmpty ? title : null,
      author: author is String && author.isNotEmpty ? author : null,
      duration: _durationOf(lockup),
    );
  }

  /// The runtime lives in the badge drawn over the thumbnail, as `3:55`.
  static Duration? _durationOf(Map<Object?, Object?> lockup) {
    final overlays = _dig(lockup, [
      'contentImage',
      'thumbnailViewModel',
      'overlays',
    ]);
    if (overlays is! List) return null;
    for (final overlay in overlays) {
      final badges = _dig(overlay, [
        'thumbnailBottomOverlayViewModel',
        'badges',
      ]);
      if (badges is! List) continue;
      for (final badge in badges) {
        final text = _dig(badge, ['thumbnailBadgeViewModel', 'text']);
        final duration = text is String ? parseClockDuration(text) : null;
        if (duration != null) return duration;
      }
    }
    return null;
  }

  static String? _titleOf(Object? data) {
    final title = _dig(data, [
      'microformat',
      'microformatDataRenderer',
      'title',
    ]);
    return title is String && title.isNotEmpty ? title : null;
  }

  /// Walks [node] down [path], where each step is a map key or a list index.
  static Object? _dig(Object? node, List<Object> path) {
    var current = node;
    for (final step in path) {
      if (step is int) {
        if (current is! List || step >= current.length) return null;
        current = current[step];
      } else {
        if (current is! Map) return null;
        current = current[step];
      }
    }
    return current;
  }

  /// Pulls out `var ytInitialData = {…};` and friends by brace matching, which
  /// survives the assignment being written a few different ways.
  static Map<String, dynamic>? _extractJson(String html, String name) {
    final marker = RegExp('$name"?\\]?\\s*=\\s*').firstMatch(html);
    if (marker == null) return null;

    final start = html.indexOf('{', marker.end);
    if (start < 0) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < html.length; i++) {
      final char = html[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == r'\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }
      switch (char) {
        case '"':
          inString = true;
        case '{':
          depth++;
        case '}':
          depth--;
          if (depth == 0) {
            try {
              return jsonDecode(html.substring(start, i + 1))
                  as Map<String, dynamic>;
            } on FormatException {
              return null;
            }
          }
      }
    }
    return null;
  }

  static String? _firstMatch(String text, String pattern) =>
      RegExp(pattern).firstMatch(text)?.group(1);

  /// Closes the http client, unless one was passed in.
  void close() {
    if (_ownsClient) _client.close();
  }
}

/// Parses `3:55` or `1:02:03` into a [Duration].
Duration? parseClockDuration(String text) {
  final parts = text.trim().split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  final numbers = [for (final part in parts) int.tryParse(part)];
  if (numbers.any((n) => n == null)) return null;
  final [hours, minutes, seconds] = switch (numbers) {
    [final m, final s] => [0, m!, s!],
    [final h, final m, final s] => [h!, m!, s!],
    _ => [0, 0, 0],
  };
  return Duration(hours: hours, minutes: minutes, seconds: seconds);
}

import 'dart:convert';

import 'package:festenao_youtube_player/yt_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A video of the current layout of the page.
Map<String, Object?> lockup(
  String id, {
  String? title,
  String author = 'Author',
  String length = '3:41',
}) => {
  'lockupViewModel': {
    'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
    'contentId': id,
    'contentImage': {
      'thumbnailViewModel': {
        'overlays': [
          {
            'thumbnailBottomOverlayViewModel': {
              'badges': [
                {
                  'thumbnailBadgeViewModel': {'text': length},
                },
              ],
            },
          },
        ],
      },
    },
    'metadata': {
      'lockupMetadataViewModel': {
        'title': {'content': title ?? 'Title $id'},
        'metadata': {
          'contentMetadataViewModel': {
            'metadataRows': [
              {
                'metadataParts': [
                  {
                    'text': {'content': author},
                  },
                ],
              },
            ],
          },
        },
      },
    },
  },
};

/// A video of the older layout of the page.
Map<String, Object?> renderer(
  String id, {
  String? title,
  String author = 'Author',
  String lengthSeconds = '221',
  bool playable = true,
}) => {
  'playlistVideoRenderer': {
    'videoId': id,
    'title': {
      'runs': [
        {'text': title ?? 'Title '},
        if (title == null) {'text': id},
      ],
    },
    'shortBylineText': {
      'runs': [
        {'text': author},
      ],
    },
    'lengthText': {'simpleText': '3:41'},
    'lengthSeconds': lengthSeconds,
    'isPlayable': playable,
  },
};

/// The continuation item of the current layout.
Map<String, Object?> lockupContinuation(String token) => {
  'continuationItemViewModel': {
    'continuationCommand': {
      'innertubeCommand': {
        'continuationCommand': {'token': token},
      },
    },
  },
};

/// The continuation item of the older layout.
Map<String, Object?> rendererContinuation(String token) => {
  'continuationItemRenderer': {
    'continuationEndpoint': {
      'continuationCommand': {'token': token},
    },
  },
};

/// The playlist page data: [sections] under the first tab.
Map<String, Object?> pageData(
  List<Object?> sections, {
  String title = 'My playlist',
}) => {
  'contents': {
    'twoColumnBrowseResultsRenderer': {
      'tabs': [
        {
          'tabRenderer': {
            'content': {
              'sectionListRenderer': {'contents': sections},
            },
          },
        },
      ],
    },
  },
  'microformat': {
    'microformatDataRenderer': {'title': title},
  },
};

/// The section holding the videos in the current layout.
Map<String, Object?> lockupSection(List<Object?> items) => {
  'itemSectionRenderer': {'contents': items},
};

/// The section holding the videos in the older layout.
Map<String, Object?> rendererSection(List<Object?> items) => {
  'itemSectionRenderer': {
    'contents': [
      {
        'playlistVideoListRenderer': {'contents': items},
      },
    ],
  },
};

/// A continuation response.
Map<String, Object?> continuationData(List<Object?> items) => {
  'onResponseReceivedActions': [
    {
      'appendContinuationItemsAction': {'continuationItems': items},
    },
  ],
};

String pageHtml(Map<String, Object?> data) =>
    '<html><head><title>x</title></head><body>'
    '<script>var ytInitialData = ${jsonEncode(data)};</script>'
    '<script>ytcfg.set({"INNERTUBE_API_KEY":"key",'
    '"INNERTUBE_CLIENT_VERSION":"2.0"});</script>'
    '</body></html>';

/// Youtube, faked: the page, and the continuations by token. The tokens
/// asked for are recorded in [requested].
http.Client fakeYoutube(
  Map<String, Object?> data,
  Map<String, Map<String, Object?>> continuations,
  List<String> requested,
) => MockClient((request) async {
  if (request.url.path == '/playlist') {
    return http.Response(pageHtml(data), 200);
  }
  if (request.url.path == '/youtubei/v1/browse') {
    final token = (jsonDecode(request.body) as Map)['continuation'] as String;
    requested.add(token);
    final page = continuations[token];
    return page == null
        ? http.Response('', 404)
        : http.Response(jsonEncode(page), 200);
  }
  return http.Response('', 404);
});

void main() {
  group('YoutubePlaylistPage', () {
    test('reads the lockup layout, following the video list only', () async {
      final requested = <String>[];
      final client = fakeYoutube(
        pageData([
          lockupSection([
            lockup('a', author: 'One'),
            lockup('b', length: '1:02:03'),
            lockupContinuation('more'),
          ]),
          // The playlists suggested under the list: another section, whose
          // continuation is not the videos'.
          lockupContinuation('suggested'),
        ]),
        {
          'more': continuationData([lockup('c'), lockup('a')]),
          'suggested': continuationData([lockup('zzz')]),
        },
        requested,
      );
      final page = YoutubePlaylistPage(client: client);
      final listing = await page.fetch('PL1');
      expect(listing.title, 'My playlist');
      expect(listing.entries.map((e) => e.videoId), ['a', 'b', 'c']);
      expect(listing.entries.first.title, 'Title a');
      expect(listing.entries.first.author, 'One');
      expect(listing.entries.first.duration, const Duration(seconds: 221));
      expect(
        listing.entries[1].duration,
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(requested, ['more']);
    });

    test('reads the older layout, skipping what cannot play', () async {
      final requested = <String>[];
      final client = fakeYoutube(
        pageData([
          rendererSection([
            renderer('a', title: 'The Clash - Stay Free', author: 'Shashwat'),
            renderer('b', playable: false),
            renderer('c', lengthSeconds: ''),
          ]),
          rendererContinuation('suggested'),
        ], title: 'Zog Clash Session'),
        {
          'suggested': continuationData([renderer('zzz')]),
        },
        requested,
      );
      final page = YoutubePlaylistPage(client: client);
      final listing = await page.fetch('PL2');
      expect(listing.title, 'Zog Clash Session');
      expect(listing.entries.map((e) => e.videoId), ['a', 'c']);
      expect(listing.entries.first.title, 'The Clash - Stay Free');
      expect(listing.entries.first.author, 'Shashwat');
      expect(listing.entries.first.duration, const Duration(seconds: 221));
      // Runs joined, the length read off the badge.
      expect(listing.entries[1].title, 'Title c');
      expect(listing.entries[1].duration, const Duration(seconds: 221));
      expect(requested, isEmpty);
    });

    test('pages the older layout too, up to max', () async {
      final requested = <String>[];
      final client = fakeYoutube(
        pageData([
          rendererSection([
            renderer('a'),
            renderer('b'),
            rendererContinuation('more'),
          ]),
        ]),
        {
          'more': continuationData([
            renderer('c'),
            renderer('d'),
            rendererContinuation('even-more'),
          ]),
          'even-more': continuationData([renderer('e')]),
        },
        requested,
      );
      final page = YoutubePlaylistPage(client: client);
      expect((await page.fetch('PL3', max: 3)).entries.map((e) => e.videoId), [
        'a',
        'b',
        'c',
      ]);
      expect(requested, ['more']);
      requested.clear();
      expect((await page.fetch('PL3')).entries.map((e) => e.videoId), [
        'a',
        'b',
        'c',
        'd',
        'e',
      ]);
      expect(requested, ['more', 'even-more']);
    });

    test('an empty playlist', () async {
      final client = fakeYoutube(pageData([rendererSection([])]), {}, []);
      final page = YoutubePlaylistPage(client: client);
      final listing = await page.fetch('PL4');
      expect(listing.title, 'My playlist');
      expect(listing.entries, isEmpty);
    });
  });
}

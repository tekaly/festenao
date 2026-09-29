@Tags(['live'])
library;

import 'package:festenao_youtube_player/yt_player.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hits youtube for real, so it is tagged `live` and skipped by default:
/// run it with `flutter test --run-skipped --tags live` when the page format is in doubt.
void main() {
  group('YoutubePlaylistPage', () {
    late YoutubePlaylistPage page;

    setUp(() => page = YoutubePlaylistPage());
    tearDown(() => page.close());

    test('reads a long playlist past the first page of 100', () async {
      final listing = await page.fetch('PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI');
      expect(listing.title, isNotEmpty);
      expect(listing.entries.length, greaterThan(100));
      final first = listing.entries.first;
      expect(first.videoId, hasLength(11));
      expect(first.title, isNotEmpty);
      expect(first.author, isNotEmpty);
      expect(first.duration, isNotNull);
      expect(
        listing.entries.map((e) => e.videoId).toSet(),
        hasLength(listing.entries.length),
        reason: 'entries must not repeat across continuations',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    // Youtube serves this one (15 videos) in the older layout of the page,
    // `playlistVideoRenderer` items, which used to come back empty.
    test('reads a short playlist in the older layout', () async {
      final listing = await page.fetch('PLVu2zpEl70e8');
      expect(listing.title, isNotEmpty);
      expect(listing.entries.length, greaterThanOrEqualTo(10));
      for (final entry in listing.entries) {
        expect(entry.videoId, hasLength(11));
        expect(entry.title, isNotEmpty);
        expect(entry.author, isNotEmpty);
        expect(entry.duration, isNotNull);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('honours the max', () async {
      final listing = await page.fetch(
        'PLFgquLnL59alCl_2TQvOiD5Vgm1hCaGSI',
        max: 12,
      );
      expect(listing.entries, hasLength(12));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

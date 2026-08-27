@Tags(['live'])
library;

import 'package:festenao_youtube_player/src/yt/yt_stream_choice.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

/// Hits youtube for real, so it is tagged `live` and skipped by default:
/// run it with `flutter test --run-skipped --tags live`.
///
/// This is the check that matters on the desktop, because youtube keeps
/// changing which adaptive streams it will serve to a player like mpv.
void main() {
  late yt.YoutubeExplode client;
  late YtStreamChooser chooser;

  setUp(() {
    client = yt.YoutubeExplode();
    chooser = YtStreamChooser();
  });
  tearDown(() {
    client.close();
    chooser.close();
  });

  /// Whatever is picked has to be openable the way mpv opens it, or playback
  /// dies with a 403 well after `open()` said it was fine.
  Future<void> expectPlayableChoice(String videoId) async {
    final manifest = await client.videos.streamsClient.getManifest(videoId);
    final chosen = await chooser.choose(manifest);
    expect(chosen, isNotNull, reason: 'nothing was picked for $videoId');
    expect(
      await chooser.servesOpenEndedRange(chosen!.videoUrl),
      isTrue,
      reason: 'the picked video stream will not serve mpv',
    );
    final audioUrl = chosen.audioUrl;
    if (audioUrl != null) {
      expect(
        await chooser.servesOpenEndedRange(audioUrl),
        isTrue,
        reason: 'the picked audio stream will not serve mpv',
      );
    }
  }

  test('picks a playable stream', () async {
    await expectPlayableChoice('dQw4w9WgXcQ');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'picks a playable stream for a video with restricted adaptive streams',
    () async {
      await expectPlayableChoice('fOT0BUpITw8');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('muxed streams are always served', () async {
    final manifest = await client.videos.streamsClient.getManifest(
      'fOT0BUpITw8',
    );
    expect(manifest.muxed, isNotEmpty);
    expect(
      await chooser.servesOpenEndedRange(
        manifest.muxed.withHighestBitrate().url,
      ),
      isTrue,
      reason: 'the muxed fallback has stopped working too',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}

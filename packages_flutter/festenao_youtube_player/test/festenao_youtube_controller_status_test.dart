import 'dart:async';

import 'package:festenao_youtube_player/player.dart';
import 'package:festenao_youtube_player/src/impl_backend.dart';
import 'package:festenao_youtube_player/yt_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A backend driven by the test: no platform player.
class _FakeBackend implements YtPlayerBackend {
  final _playback = ValueNotifier(const YtPlaybackState());
  final _completions = StreamController<void>.broadcast();

  @override
  void Function(YtPlaylistEntry entry)? onEntryMetadata;
  @override
  void Function(String message)? onPlaybackError;
  @override
  ValueListenable<YtPlaybackState> get playback => _playback;
  @override
  Stream<void> get completions => _completions.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<YtResolvedPlaylist> resolve(YtSource source) async =>
      throw UnimplementedError();
  @override
  Future<void> open(
    YtPlaylistEntry entry, {
    bool autoPlay = true,
    Duration? start,
  }) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setMuted(bool muted) async {}
  @override
  Future<void> setPlaybackRate(double rate) async {}
  @override
  Widget buildVideoView(BuildContext context) => const SizedBox();
  @override
  Future<void> dispose() async {
    await _completions.close();
    _playback.dispose();
  }

  /// The platform player reports [playing] at [position].
  void report({required bool playing, Duration position = Duration.zero}) {
    _playback.value = _playback.value.copyWith(
      playing: playing,
      position: position,
    );
  }

  void complete() => _completions.add(null);
}

void main() {
  test('a video replayed from the player own controls is playing again, '
      'not ended', () async {
    var backend = _FakeBackend();
    var controller = FestenaoBackendYoutubeController(
      options: FesteneaoYoutubeOptions(videoId: 'dQw4w9WgXcQ'),
      backend: backend,
    );
    addTearDown(controller.selfDispose);
    await controller.ready;
    backend.report(playing: true, position: const Duration(seconds: 1));
    expect(controller.state.status, FestenaoYoutubePlayerStatus.playing);
    backend.report(playing: false, position: const Duration(seconds: 3));
    backend.complete();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.status, FestenaoYoutubePlayerStatus.ended);
    // Replay pressed in the player's own controls (showControls).
    backend.report(playing: true, position: const Duration(milliseconds: 100));
    expect(controller.state.status, FestenaoYoutubePlayerStatus.playing);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a playback error the player recovers from is playing again', () async {
    var backend = _FakeBackend();
    var controller = FestenaoBackendYoutubeController(
      options: FesteneaoYoutubeOptions(videoId: 'dQw4w9WgXcQ'),
      backend: backend,
    );
    addTearDown(controller.selfDispose);
    await controller.ready;
    backend.onPlaybackError!('network');
    expect(controller.state.status, FestenaoYoutubePlayerStatus.error);
    backend.report(playing: true, position: const Duration(seconds: 2));
    expect(controller.state.status, FestenaoYoutubePlayerStatus.playing);
  }, timeout: const Timeout(Duration(seconds: 30)));
}

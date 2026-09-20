---
name: festenao-youtube-player-widget
description: >-
  Use when embedding a single YouTube video in a Flutter screen with ready made
  controls: FestenaoYoutubePlayer(controller:), FestenaoYoutubeController(options:),
  FesteneaoYoutubeOptions(videoId:, autoPlay:, showControls:), the
  stateStream of FestenaoYoutubePlayerState (status, position, duration,
  playbackRate), the FestenaoYoutubePlayerStatus enum, play/pause/stop/seekTo,
  and swapping festenaoYoutubePlayerService (FestenaoYoutubePlayerService,
  FestenaoYoutubeControllerBase, festenaoYoutubePlayerServiceDefault) for a
  fake in tests, from package:festenao_youtube_player/player.dart.
---

# Single video player (festenao_youtube_player)

`player.dart` is the high level half of the package: hand a video id to a
controller, put `FestenaoYoutubePlayer` in the tree and get a playing video
with the platform's own controls — youtube's iframe player on the web,
media_kit (mpv) everywhere else. For a playlist, or to draw your own controls,
use `yt_player.dart` instead (see the `festenao-youtube-player-playlist`
skill).

## Guidelines

* Dependency (not on pub.dev, git only):

  ```yaml
  dependencies:
    festenao_youtube_player:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_youtube_player
  ```

  Desktop playback goes through mpv, so a Linux dev/CI box needs
  `sudo apt install libmpv-dev mpv` (and `ubuntu-restricted-extras
  libavcodec-extra` for the usual codecs). The web needs nothing extra.

* Import `package:festenao_youtube_player/player.dart`. Never import
  `package:festenao_youtube_player/src/...`.
* Watch the spelling: the options class is **`FesteneaoYoutubeOptions`** (with
  an extra `e`), while everything else is `Festenao...`. It is
  `FesteneaoYoutubeOptions({required String videoId, bool autoPlay = false,
  bool showControls = true})`.
* `videoId` is the bare **11 character id**, not a url. To accept what a user
  pastes, run it through `parseYtSource` from
  `package:festenao_youtube_player/yt_player.dart` and take the `videoId` of
  the `YtVideoSource`.
* `FestenaoYoutubeController({required FesteneaoYoutubeOptions options})` is a
  factory that delegates to `festenaoYoutubePlayerService.newController(...)`.
  Create it **once** (a `late final` field of the `State`, a provider), never
  in `build()`: rebuilding it restarts the video. The options are fixed at
  construction — to play another video, build another controller.
* `FestenaoYoutubePlayer({Key? key, required FestenaoYoutubeController
  controller})` just asks the service for the platform widget. It fills the box
  it is given, so wrap it in an `AspectRatio(aspectRatio: 16 / 9, ...)`, a
  `SizedBox` or an `Expanded` — it has no intrinsic size.
* Driving it: `play()`, `pause()`, `stop()` and `seekTo(Duration duration,
  {bool allowSeekAhead = false})`. `allowSeekAhead: false` is the "scrubbing"
  mode (do not jump past what is buffered) — pass `true` when the user lets go
  of the slider, as in the package example.
* `controller.stateStream` is a `Stream<FestenaoYoutubePlayerState>` with
  `status`, `position`, `duration` and `playbackRate`. It is a seeded value
  stream, so a `StreamBuilder` gets a value on the first frame; that value is
  `FestenaoYoutubePlayerStatus.unknown` with zero durations until the player is
  ready, so guard on `duration == Duration.zero` before computing a progress
  ratio. Statuses: `error`, `unknown`, `loading`, `ready`, `playing`, `paused`,
  `buffering`, `ended`.
* Disposal: the controller is an `AutoDisposable`, so it is released with
  `selfDispose()`. In a widget prefer `AutoDisposeBaseState` +
  `audiAddDisposable(...)` (from
  `package:festenao_common_flutter/common_utils_flutter.dart`), which does it for you
  in `dispose()`.
* Web caveats: the browser blocks autoplay with sound, so a video started with
  `autoPlay: true` usually starts muted, and the iframe player draws youtube's
  own controls (`showControls`). A transparent `pointer_interceptor` layer
  keeps taps and focus with Flutter.
* `festenaoYoutubePlayerService` is a mutable global of type
  `FestenaoYoutubePlayerService` (`newController`, `newPlayer`). Replace it to
  plug another implementation in — a fake in a widget test — and restore
  `festenaoYoutubePlayerServiceDefault` afterwards. Set it **before** any
  controller is created; existing controllers keep the old implementation.
  A fake controller should extend the exported
  `FestenaoYoutubeControllerBase`, which brings the state subject and its
  `addState(...)`/`state` members; it still has to provide `options`, `play`,
  `pause`, `stop` and `seekTo`.
* Anti-patterns: passing a full `https://www.youtube.com/watch?v=...` as
  `videoId`; creating the controller in `build()`; putting the player in an
  unbounded `Column`/`ListView` without a sized box; expecting `setPlaybackRate`
  here (there is none on this controller — use the `yt_player.dart` backend);
  using this widget for a playlist (it plays one video).
* Testing: a real player needs a platform (mpv or a browser), so unit/widget
  tests swap `festenaoYoutubePlayerService` for a fake service returning a fake
  controller and a plain placeholder widget, and assert on what the ui does
  with `stateStream`.

## Examples

### A player screen with its own progress bar

```dart
import 'package:festenao_common_flutter/common_utils_flutter.dart';
import 'package:festenao_youtube_player/player.dart';
import 'package:flutter/material.dart';

/// Plays one video, with the platform controls plus a progress slider of ours.
class VideoScreen extends StatefulWidget {
  /// The 11 character youtube video id.
  final String videoId;

  /// Constructor.
  const VideoScreen({super.key, required this.videoId});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

/// AutoDisposeBaseState calls selfDispose() on everything added with
/// audiAddDisposable when the state is disposed.
class _VideoScreenState extends AutoDisposeBaseState<VideoScreen> {
  // Created once, never in build().
  late final _controller = audiAddDisposable(
    FestenaoYoutubeController(
      options: FesteneaoYoutubeOptions(
        videoId: widget.videoId,
        autoPlay: true,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Video')),
    body: ListView(
      children: [
        // The player has no intrinsic size.
        AspectRatio(
          aspectRatio: 16 / 9,
          child: FestenaoYoutubePlayer(controller: _controller),
        ),
        StreamBuilder<FestenaoYoutubePlayerState>(
          stream: _controller.stateStream,
          builder: (context, snapshot) {
            var state = snapshot.data;
            var status = state?.status ?? FestenaoYoutubePlayerStatus.unknown;
            var durationMs = state?.duration.inMilliseconds ?? 0;
            var positionMs = state?.position.inMilliseconds ?? 0;
            // Zero until the player is ready.
            if (durationMs == 0) {
              return ListTile(title: Text(status.name));
            }
            var ratio = (positionMs / durationMs).clamp(0.0, 1.0);
            return Column(
              children: [
                Slider(
                  value: ratio,
                  onChanged: (value) => _controller.seekTo(
                    Duration(milliseconds: (durationMs * value).toInt()),
                  ),
                  // Let go of the slider: jump for real.
                  onChangeEnd: (value) => _controller.seekTo(
                    Duration(milliseconds: (durationMs * value).toInt()),
                    allowSeekAhead: true,
                  ),
                ),
                ListTile(
                  title: Text(status.name),
                  subtitle: Text('${state!.position} / ${state.duration}'),
                ),
              ],
            );
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _controller.play,
              icon: const Icon(Icons.play_circle, size: 40),
            ),
            IconButton(
              onPressed: _controller.pause,
              icon: const Icon(Icons.pause_circle, size: 40),
            ),
            IconButton(
              onPressed: _controller.stop,
              icon: const Icon(Icons.stop_circle, size: 40),
            ),
          ],
        ),
      ],
    ),
  );
}
```

### From a pasted link to a controller

```dart
import 'package:festenao_youtube_player/player.dart';
import 'package:festenao_youtube_player/yt_player.dart';

/// The options class is spelled `Festeneao...`, and videoId is the bare
/// 11 character id, never a url: parse whatever the user pasted first.
FesteneaoYoutubeOptions? optionsFromLink(String pasted) {
  var source = parseYtSource(pasted);
  return switch (source) {
    YtVideoSource(:var videoId) => FesteneaoYoutubeOptions(
      videoId: videoId,
      autoPlay: true,
    ),
    // A playlist link needs the yt_player.dart backend, not this player.
    YtPlaylistSource() => null,
    null => null,
  };
}

/// Only build the controller once the link parsed.
FestenaoYoutubeController? controllerFromLink(String pasted) {
  var options = optionsFromLink(pasted);
  return options == null ? null : FestenaoYoutubeController(options: options);
}
```

### Faking the service in a widget test

```dart
import 'package:festenao_youtube_player/player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controller with no platform behind it. FestenaoYoutubeControllerBase
/// brings the state subject, `state` and `addState`.
class FakeYoutubeController extends FestenaoYoutubeControllerBase {
  @override
  final FesteneaoYoutubeOptions options;

  /// Starts ready, with a known duration.
  FakeYoutubeController(this.options) {
    addState(
      FestenaoYoutubePlayerState(
        status: FestenaoYoutubePlayerStatus.ready,
        duration: const Duration(minutes: 3),
      ),
    );
  }

  @override
  void play() =>
      addState(state.copyWith(status: FestenaoYoutubePlayerStatus.playing));

  @override
  void pause() =>
      addState(state.copyWith(status: FestenaoYoutubePlayerStatus.paused));

  @override
  void stop() =>
      addState(state.copyWith(status: FestenaoYoutubePlayerStatus.ended));

  @override
  void seekTo(Duration duration, {bool allowSeekAhead = false}) =>
      addState(state.copyWith(position: duration));
}

/// Returns fakes instead of the platform player.
class FakeYoutubeService implements FestenaoYoutubePlayerService {
  @override
  FestenaoYoutubeController newController({
    required FesteneaoYoutubeOptions options,
  }) => FakeYoutubeController(options);

  @override
  Widget newPlayer({
    Key? key,
    required FestenaoYoutubeController controller,
  }) => Container(key: key, color: Colors.black);
}

void main() {
  setUp(() => festenaoYoutubePlayerService = FakeYoutubeService());
  // Always put the real one back.
  tearDown(() => festenaoYoutubePlayerService = festenaoYoutubePlayerServiceDefault);

  testWidgets('shows the status of the player', (tester) async {
    // The service must be swapped before the controller is created.
    var controller = FestenaoYoutubeController(
      options: FesteneaoYoutubeOptions(videoId: 'dQw4w9WgXcQ'),
    );
    addTearDown(controller.selfDispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: FestenaoYoutubePlayer(controller: controller),
            ),
            StreamBuilder<FestenaoYoutubePlayerState>(
              stream: controller.stateStream,
              builder: (context, snapshot) =>
                  Text(snapshot.data?.status.name ?? 'none'),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('ready'), findsOneWidget);

    controller.play();
    await tester.pump();
    expect(find.text('playing'), findsOneWidget);
  });
}
```

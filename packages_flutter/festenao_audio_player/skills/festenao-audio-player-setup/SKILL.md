---
name: festenao-audio-player-setup
description: >-
  Use when adding audio playback to a festenao Flutter app with
  festenao_audio_player: the player.dart import (AppAudioPlayer,
  AppAudioPlayerSong, AppAudioPlayerState, AppAudioPlayerStateEnum,
  SongAudioPlayer, the just_audio implementation AppAudioPlayerJustAudio and
  appAudioPlayerJustAudio), the ready made AppAudioPlayerWidget controls,
  formatSongDuration, playBytes / playSong, positionStream / stateStream, the
  cache.dart import (initCacheDatabase, globalCacheOrNull) that playSong
  needs, and debugPlayerDumpWriteLn / debugJustAudioPlayer tracing.
---

# Festenao audio player (festenao_audio_player)

`festenao_audio_player` is the festenao bundle of the playlr audio player:
one import for the `AppAudioPlayer` abstraction and its just_audio
implementation, plus a ready made control bar widget and a duration
formatter. Content always reaches the player as bytes, so one code path plays
a download, an asset, a file or a url on every platform.

## Guidelines

* Dependency (git, not on pub.dev); desktop backends are federated plugins
  the app itself must list:
  ```yaml
  dependencies:
    festenao_audio_player:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_audio_player
      version: '>=0.2.0'
    just_audio_mpv: '>=0.1.7' # Linux (needs `sudo apt-get install mpv`)
    just_audio_windows: '>=0.2.3' # Windows
  ```
* Imports: `package:festenao_audio_player/player.dart` re-exports
  `playlr_audio_player/player.dart` (`AppAudioPlayer`, `AppAudioPlayerSong`,
  `AppAudioPlayerState`, `AppAudioPlayerStateEnum`, `SongAudioPlayer`,
  `debugPlayerDumpWriteLn`), `playlr_audio_player_just_audio/player.dart`
  (`AppAudioPlayerJustAudio`, `appAudioPlayerJustAudio`,
  `debugJustAudioPlayer`) and adds `formatSongDuration` and
  `AppAudioPlayerWidget`. `package:festenao_audio_player/cache.dart`
  re-exports the playlr file cache (`initCacheDatabase`, `globalCacheOrNull`,
  `FileCacheDatabase`).
* One player per app: `appAudioPlayerJustAudio` (singleton) or
  `AppAudioPlayerJustAudio()`, held as an `AppAudioPlayer` so nothing else
  knows about just_audio. It keeps a pool of 2 `SongAudioPlayer`s; the
  current one is `currentPlayer`.
* Feeding content: `playBytes(bytes)` / `loadBytes(bytes)` when the audio
  bytes are at hand (the app fetched and cached them); `playSong(song)` /
  `loadSong(song)` for an `AppAudioPlayerSong(url)`, `.asset(path)` or
  `.file(path)` read through the global cache, which needs
  `await initCacheDatabase(packageName: 'com.example.app')` once at startup
  (`loadSong` throws `StateError` otherwise). Both `playX` stop the current
  song first and return before playback ends.
* Controls: `play`, `pause`, `resume`, `stop`, `seek(Duration)`,
  `setVolume(0..1)`, `setPlaybackRate`, `getDuration`, `getCurrentPosition`,
  `getCurrentPositionSync`; extension helpers `forward(duration)`,
  `playFromTo(from:, to:, playbackRate:)`, `fadeIn`, `fadeOut`,
  `isPlayingSync()`.
* State: `stateStream` emits `AppAudioPlayerState` on change (`stateEnum`
  none / preparing / ready / completed, `playing`, `duration`, `position`
  extrapolated while playing, `isReady`); `stateValue` is the current one;
  `positionStream` (`Duration?`) ticks about every 100 ms while playing.
  `completed` is the end of the song: play the next one from there.
* `AppAudioPlayerWidget(player:, song:)`: a `Row` with skip to start, play
  (plays `song` when not null, else `player.play()`), pause, resume, stop,
  skip to end, the position and a seek `Slider` (`Expanded`): give it a
  bounded width (a `Column` child, not an unbounded `Row`).
* `formatSongDuration(duration)` gives `m:ss` (`0:00`, `1:05`, `12:07`),
  minutes not padded, milliseconds truncated.
* Web: the first playback must follow a user gesture (autoplay policy); a
  blocked start shows as `preparing`/`ready` never turning `playing`.
  Widget tests: the platform channels never answer under `flutter test`,
  so an awaited `playBytes`/`playSong` hangs; keep the player behind an
  interface and test the pure parts (`formatSongDuration`).
* Tracing: `debugPlayerDumpWriteLn = print` (facade state events) and
  `debugJustAudioPlayer = true` (just_audio events).

## Examples

### Composition root

```dart
import 'package:festenao_audio_player/cache.dart';
import 'package:festenao_audio_player/player.dart';
import 'package:flutter/material.dart';

/// The one player of the app, seen as the abstraction everywhere else.
final AppAudioPlayer audioPlayer = appAudioPlayerJustAudio;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Only needed by playSong/loadSong (url, asset and file sources).
  await initCacheDatabase(packageName: 'com.example.myapp');
  runApp(const MaterialApp(home: Scaffold(body: Text('ready'))));
}
```

### A screen with the control bar and a position label

```dart
import 'package:festenao_audio_player/player.dart';
import 'package:flutter/material.dart';

class SongScreen extends StatelessWidget {
  final AppAudioPlayer player;
  final AppAudioPlayerSong song;

  const SongScreen({super.key, required this.player, required this.song});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Player')),
      body: Column(
        children: [
          AppAudioPlayerWidget(player: player, song: song),
          StreamBuilder<AppAudioPlayerState>(
            stream: player.stateStream,
            builder: (context, snapshot) {
              var state = snapshot.data;
              var duration = state?.duration;
              var position = state?.position ?? Duration.zero;
              return Text(
                '${formatSongDuration(position)} / '
                '${duration == null ? '-:--' : formatSongDuration(duration)}',
              );
            },
          ),
        ],
      ),
    );
  }
}
```

### Playing bytes, an asset or a url

```dart
import 'package:festenao_audio_player/player.dart';
import 'package:flutter/services.dart';

/// Bytes the app already has (no cache involved).
Future<void> playAsset(AppAudioPlayer player, String assetPath) async {
  var data = await rootBundle.load(assetPath);
  await player.playBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

/// Through the global cache (initCacheDatabase called at startup).
Future<void> playUrl(AppAudioPlayer player, String url) =>
    player.playSong(AppAudioPlayerSong(url));

/// Chain songs: play the next one when the current one completes.
void playNextOnCompletion(AppAudioPlayer player, void Function() next) {
  player.stateStream.listen((state) {
    if (state.stateEnum == AppAudioPlayerStateEnum.completed) {
      next();
    }
  });
}
```

### Test of the pure part

```dart
import 'package:festenao_audio_player/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatSongDuration', () {
    expect(formatSongDuration(Duration.zero), '0:00');
    expect(formatSongDuration(const Duration(seconds: 65)), '1:05');
    expect(formatSongDuration(const Duration(milliseconds: 900)), '0:00');
  });
}
```

### Tracing a platform problem

```dart
import 'package:festenao_audio_player/player.dart';

void enablePlayerTracing() {
  debugJustAudioPlayer = true; // just_audio events
  debugPlayerDumpWriteLn = print; // facade state events
}
```

## Common mistakes

* `playSong` without `initCacheDatabase`: `StateError`.
* Importing `package:just_audio` or `playlr_audio_player_just_audio` in
  screens: only the composition root picks the implementation.
* Starting playback in `initState` on the web (autoplay blocked).
* Forgetting `just_audio_mpv` / `just_audio_windows` in the app pubspec: a
  desktop build that plays nothing.

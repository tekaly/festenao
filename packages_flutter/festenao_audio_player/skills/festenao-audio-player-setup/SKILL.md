---
name: festenao-audio-player-setup
description: >-
  Use when adding audio playback to a festenao Flutter app with
  festenao_audio_player: the player.dart import (AppAudioPlayer,
  AppAudioPlayerSong, AppAudioPlayerState, AppAudioPlayerStateEnum,
  SongAudioPlayer, the just_audio implementation AppAudioPlayerJustAudio and
  appAudioPlayerJustAudio), the ready made AppAudioPlayerWidget controls,
  formatSongDuration, playBytes / playSong / playUri, loaded,
  positionStream / stateStream, the cache.dart import (initCacheDatabase,
  globalCacheOrNull) that playSong needs, platforms (Linux mpv, Windows
  sqflite ffi) and debugPlayerDumpWriteLn tracing.
---

# Festenao audio player (festenao_audio_player)

`festenao_audio_player` is the festenao bundle of the playlr audio player:
one import for the `AppAudioPlayer` abstraction and its just_audio
implementation, plus a ready made control bar widget and a duration
formatter. Content reaches the player as bytes (`playBytes`, `playSong`
through the file cache: a download, an asset or a file) or as a streamed url
(`playUri`).

## Guidelines

* Dependency (git, not on pub.dev); the screens use `material_ui`:
  ```yaml
  dependencies:
    festenao_audio_player:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_audio_player
    material_ui: ">=1.5.0"
  ```
  The Linux and Windows backends (`just_audio_mpv`, `just_audio_windows`)
  come with it: Flutter registers a federated implementation found in the
  dependencies, the app lists them only to pin a version.
* Platforms: Android, iOS, macOS, web, Linux (the `mpv` program installed:
  `sudo apt-get install mpv`), Windows (call `sqfliteFfiInit()` from
  `sqflite_common_ffi` before `initCacheDatabase`: the cache index is a
  sqflite database).
* Imports: `package:festenao_audio_player/player.dart` re-exports
  `playlr_audio_player/player.dart` (`AppAudioPlayer`, `AppAudioPlayerSong`,
  `AppAudioPlayerState`, `AppAudioPlayerStateEnum`, `SongAudioPlayer`,
  `debugPlayerDumpWriteLn`), `playlr_audio_player_just_audio/player.dart`
  (`AppAudioPlayerJustAudio`, `appAudioPlayerJustAudio`) and adds
  `formatSongDuration` and `AppAudioPlayerWidget`.
  `package:festenao_audio_player/cache.dart` re-exports the playlr file cache
  (`initCacheDatabase`, `globalCacheOrNull`, `FileCacheDatabase`).
* One player per app: `appAudioPlayerJustAudio` (singleton) or
  `AppAudioPlayerJustAudio()`, held as an `AppAudioPlayer` so nothing else
  knows about just_audio. It keeps a pool of 2 `SongAudioPlayer`s (the
  current one and the previous one); the current one is `currentPlayer`.
* Feeding content: `playBytes(bytes)` / `loadBytes(bytes)` when the audio
  bytes are at hand (no cache); `playSong(song)` / `loadSong(song)` for an
  `AppAudioPlayerSong(url)`, `.asset(key)` or `.file(path)` read through the
  global cache, which needs `await initCacheDatabase(packageName:
  'com.example.app')` once at startup (`loadSong` throws `StateError`
  otherwise); `playUri(uri)` / `loadUri(uri)` stream an url (nothing
  downloaded first). The `playX` calls stop the current song first and
  return once the new one started, not when it ends.
* `await songPlayer.loaded` (the `SongAudioPlayer` of `loadBytes` /
  `loadSong`) waits for the source and throws when the platform cannot load
  it; `loadUri` already waits. Seek after `loaded`, not before.
* Controls: `play`, `pause`, `resume`, `stop`, `seek(Duration)`,
  `setVolume(0..1)`, `setPlaybackRate`, `getDuration`, `getCurrentPosition`,
  `getCurrentPositionSync`; extension helpers `forward(duration)`,
  `playFromTo(from:, to:, playbackRate:)`, `fadeIn`, `fadeOut`,
  `isPlayingSync()`. just_audio's `play()` / `resume()` complete when the
  song is paused, stopped or done: never await them to know that playback
  started.
* State: `stateStream` emits `AppAudioPlayerState` on change (`stateEnum`
  none / preparing / ready / completed, `playing`, `duration`, `position`
  extrapolated while playing, `isReady`); `stateValue` is the current one;
  `positionStream` (`Duration?`) ticks about every 100 ms while playing.
  `completed` is the end of the song: play the next one from there.
* `AppAudioPlayerWidget(player:, song:)`: a `Row` with skip to start, play
  (plays `song` when not null, through the cache, else `player.play()`),
  pause, resume, stop, skip to end, the position and a seek `Slider`
  (`Expanded`): give it a bounded width (a `Column` child, not an unbounded
  `Row`). Releasing the slider seeks and resumes, even a paused song.
* `formatSongDuration(duration)` gives `m:ss` (`0:00`, `1:05`, `12:07`),
  minutes not padded, milliseconds truncated.
* Overlapping loads: a second `playSong` / `playUri` made while the first
  song still loads plays both songs, the first one out of reach of
  `pause()` / `stop()`. Disable the play action while a song loads, or wait
  for the previous call.
* Linux: `just_audio_mpv` runs on `mpv_dart` 0.0.1, which puts every player
  on one IPC socket (`/tmp/MPV_Dart.sock`); with the pool of 2 the second
  song can break the first one, and a track may stay `preparing`. An app
  that must play well on Linux uses `playlr_audio_player_blue_fire`
  (`appAudioPlayerBlueFire`) there, as the playlr example app does.
* Web: the first playback must follow a user gesture (autoplay policy); a
  blocked start shows as `preparing`/`ready` never turning `playing`.
* Widget tests: `flutter test` has no native player, the player calls fail
  with a `MissingPluginException`; keep the player behind the
  `AppAudioPlayer` interface (a fake in tests) and test the pure parts
  (`formatSongDuration`).
* Tracing: `debugPlayerDumpWriteLn = print` traces the facade state events
  and the just_audio events (`debugJustAudioPlayer` is exported but read by
  nothing).

## Examples

### Composition root

```dart
import 'package:festenao_audio_player/cache.dart';
import 'package:festenao_audio_player/player.dart';
import 'package:material_ui/material_ui.dart';

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
import 'package:material_ui/material_ui.dart';

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

### Playing bytes, a url, or starting at a position

```dart
import 'package:festenao_audio_player/player.dart';
import 'package:flutter/services.dart';

/// Bytes the app already has (no cache involved).
Future<void> playAsset(AppAudioPlayer player, String assetKey) async {
  var data = await rootBundle.load(assetKey);
  await player.playBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

/// Through the global cache (initCacheDatabase called at startup).
Future<void> playUrl(AppAudioPlayer player, String url) =>
    player.playSong(AppAudioPlayerSong(url));

/// Streamed, nothing downloaded first.
Future<void> streamUrl(AppAudioPlayer player, String url) =>
    player.playUri(Uri.parse(url));

/// Load, wait for the source, seek, then play (resume not awaited: on
/// just_audio it completes at the end of the song).
Future<void> playFrom(
  AppAudioPlayer player,
  AppAudioPlayerSong song,
  Duration position,
) async {
  var songPlayer = await player.loadSong(song);
  await songPlayer.loaded;
  await songPlayer.seek(position);
  songPlayer.resume().ignore();
}

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
  // Facade state events and the just_audio events.
  debugPlayerDumpWriteLn = print;
}
```

## Common mistakes

* `playSong` without `initCacheDatabase`: `StateError`.
* Awaiting `play()` / `resume()` to know that playback started: on just_audio
  it completes at the end of the song.
* Two `playSong` calls in a row (a double tap): both songs play.
* Importing `package:just_audio` or `playlr_audio_player_just_audio` in
  screens: only the composition root picks the implementation.
* Starting playback in `initState` on the web (autoplay blocked).
* Importing `package:flutter/material.dart` in new code (Flutter beta
  deprecates it): use `package:material_ui/material_ui.dart`.

# festenao_audio_player

The audio player of the festenao apps, in one dependency: the
[playlr_audio_player](https://github.com/tekaly/playlr/tree/main/packages_flutter/playlr_audio_player)
facade (`AppAudioPlayer`) with its just_audio implementation
(`appAudioPlayerJustAudio`), a ready made control bar
(`AppAudioPlayerWidget`) and `formatSongDuration`.

- `package:festenao_audio_player/player.dart`: the player, the songs, the
  state streams, the widget, `formatSongDuration`.
- `package:festenao_audio_player/cache.dart`: `initCacheDatabase`, the file
  cache that `playSong` reads the audio through (urls downloaded once).

## Getting started

Not on pub.dev, add the git dependency (and `material_ui` for the screens):

```yaml
dependencies:
  festenao_audio_player:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_audio_player
  material_ui: ">=1.5.0"
```

```dart
import 'package:festenao_audio_player/cache.dart';
import 'package:festenao_audio_player/player.dart';
import 'package:material_ui/material_ui.dart';

/// One player for the whole app, seen as the abstraction everywhere else.
final AppAudioPlayer audioPlayer = appAudioPlayerJustAudio;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Once, before the first playSong (the play button of the widget).
  await initCacheDatabase(packageName: 'com.example.myplayer');
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            // Start, play, pause, resume, stop, end, position, seek slider.
            AppAudioPlayerWidget(
              player: audioPlayer,
              song: AppAudioPlayerSong('https://example.com/audio/song.mp3'),
            ),
          ],
        ),
      ),
    ),
  );
}
```

The same app is in [example/main.dart](example/main.dart).

## Platforms

Android, iOS, macOS and the web: nothing to add. Linux and Windows go
through `just_audio_mpv` and `just_audio_windows`, which come with the
dependency (no need to list them). On Linux the `mpv` program must be
installed (`sudo apt-get install mpv`); on Windows call `sqfliteFfiInit()`
(`sqflite_common_ffi`) before `initCacheDatabase` (the cache index is a
sqflite database).

## Pitfalls

- `playSong`/`loadSong` need `initCacheDatabase` first (`StateError`
  otherwise). Bytes the app already has play with `playBytes(bytes)`, no
  cache; `playUri(uri)` streams an url.
- `playSong`/`playUri` return once the song started. A second call made while
  the first song still loads plays both: disable the play action while a song
  loads.
- just_audio's `play()`/`resume()` complete at the end of the song, not when
  it starts: do not await them before doing something else.
- `AppAudioPlayerWidget` resumes playback when the seek slider is released,
  even if the song was paused.
- Linux: `just_audio_mpv` uses `mpv_dart` 0.0.1, which puts every player on
  the same IPC socket (`/tmp/MPV_Dart.sock`): the player keeps the previous
  song player alive, and the playlr example app saw the second song break
  the first one. An app that must play well on Linux uses
  `playlr_audio_player_blue_fire` there.
- Web: the first play must follow a user gesture (browser autoplay policy).
- `flutter test` has no native player: the player calls fail with a
  `MissingPluginException`. Test the app logic against the `AppAudioPlayer`
  abstraction, and pure helpers such as `formatSongDuration`.

Package skill (for AI coding agents, `skills/`): `festenao-audio-player-setup`.
Install it in an app depending on it with:

```bash
dart run skills@ get -p festenao_audio_player
```

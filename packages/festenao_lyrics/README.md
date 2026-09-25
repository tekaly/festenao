## Lyrics

Lyrics for karaoke and songbooks, pure Dart: the model (`CvLyrics`, every
time in media milliseconds), the formats (LRC and enhanced LRC, SRT/WebVTT,
the lyrics text format which also reads ChordPro), the effective timing
(`LyricsTimeline`), what a player plays of a song (`computePlayRanges`), a
smooth display position (`LyricsClock`) and the timing editor logic
(`LyricsTapEditor`). The Flutter display is `festenao_lyrics_player`
(`karaoke_player.dart`).

Setup `pubspec.yaml`:

```yaml
  festenao_lyrics:
    git:
      url: https://github.com/tekaly/festenao
      path: packages/festenao_lyrics
    version: '>=0.1.0'
```

```dart
import 'package:festenao_lyrics/festenao_lyrics.dart';
```

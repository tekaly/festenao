---
name: festenao-lyrics-player-karaoke
description: >-
  Use when a Flutter screen shows festenao_lyrics lyrics (CvLyrics) as
  karaoke following a media position, or as songbook text with chords:
  KaraokeLyricsView (lyrics, positionMs, layout KaraokeLyricsLayout.page /
  scroll, linesPerPage, style, leadInGapMs, leadInMs), KaraokeLyricsStyle
  (dark, light, fromTheme), SongbookLyricsView (showChords, transpose,
  textStyle, chordStyle) from package:festenao_lyrics_player/karaoke_player.dart.
---

# Karaoke and songbook display (festenao_lyrics_player)

`karaoke_player.dart` draws the lyrics model of `festenao_lyrics`
(`festenao_lyrics.dart`, re-exported): `KaraokeLyricsView` follows a media
position, `SongbookLyricsView` is the text with the chords above the
syllables. (The older `lyrics_player.dart` draws the `tekaly_lyrics` model.)

## Guidelines

* Dependency (not on pub.dev, git only):

  ```yaml
  dependencies:
    festenao_lyrics_player:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_lyrics_player
  ```

* `KaraokeLyricsView(lyrics:, positionMs:)`: [positionMs] is a function read
  on every frame (a ticker), return the media position in milliseconds —
  typically `LyricsClock.positionMs` fed by the player, minus the output
  latency of the device. Not the position stream itself: it is too coarse
  for a syllable wipe.
* It uses the finest timing there is: a progressive wipe inside each
  syllable, estimated syllables for a line timed by its start and end, the
  whole line, or the page only; untimed lyrics show as plain text.
* `layout`: `KaraokeLyricsLayout.page` (the default: `linesPerPage` lines,
  or the explicit pages, flipped at their show time) or `.scroll` (every
  line, the current one kept in view). Lead-in dots show before a line that
  follows a gap of `leadInGapMs` (3 s).
* Style: `KaraokeLyricsStyle.dark` (yellow on black), `.light(sung:)`,
  `.fromTheme(theme)`; the font size is a fraction of the width
  (`fontSizeFactor`) capped by `maxFontSize`.
* Give it a bounded box. It keeps a ticker running: in widget tests pump
  durations, `pumpAndSettle` never settles.
* `SongbookLyricsView(lyrics:, showChords:, transpose:, textStyle:,
  chordStyle:)` is not scrollable: put it in a scroll view.

## Examples

```dart
import 'package:festenao_lyrics_player/karaoke_player.dart';
import 'package:flutter/material.dart';

class KaraokePane extends StatelessWidget {
  final CvLyrics lyrics;
  final LyricsClock clock;

  const KaraokePane({super.key, required this.lyrics, required this.clock});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 240,
    child: KaraokeLyricsView(
      lyrics: lyrics,
      positionMs: () => clock.positionMs,
      style: KaraokeLyricsStyle.fromTheme(Theme.of(context)),
    ),
  );
}
```

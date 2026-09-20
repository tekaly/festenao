---
name: festenao-lyrics-player-widget
description: >-
  Use when a Flutter screen must display scrolling, karaoke style synced lyrics
  from an LRC string: parseLyricLrc / parseLyricDurationLrc, LyricsData,
  LyricsLineData, LyricsPartData, LyricsDataController (play(speed:),
  update(Duration), lyricsData), the LyricsDataPlayer widget and
  LyricsDataPlayerStyle (defaultDark, defaultLight, copyWith, onTextStyle,
  offTextStyle, textScaler, lineCount, scrollDuration) from
  package:festenao_lyrics_player/lyrics_player.dart.
---

# Lyrics player (festenao_lyrics_player)

`festenao_lyrics_player` renders time-synced lyrics: an LRC string is parsed
into a `LyricsData`, a `LyricsDataController` tracks which line and which word
is current at a given time, and `LyricsDataPlayer` paints them in an
auto-scrolling list, highlighting what has already been sung.

## Guidelines

* Dependency (not on pub.dev, git only):

  ```yaml
  dependencies:
    festenao_lyrics_player:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_lyrics_player
  ```

* Single import: `package:festenao_lyrics_player/lyrics_player.dart`. It
  re-exports `package:tekaly_lyrics/lyrics.dart`, so the model and the parser
  come with it — do not import `tekaly_lyrics` separately, and never import
  `package:festenao_lyrics_player/src/...`.
* Parsing: `parseLyricLrc(String)` returns a `LyricsData` (`title`, `artist`,
  `duration`, `lines`). It accepts both plain LRC lines (`[00:12.34]text`) and
  enhanced, per-word LRC (`[00:12.34]<00:12.5>word <00:13.0>word`): a line
  becomes a `LyricsLineSingleContent` or a `LyricsLineMultiContent`, each part a
  `LyricsPartData(time:, text:)`. `parseLyricDurationLrc('00:12.34')` parses a
  single timestamp. `LyricsDataExt` adds `toLrcLines()` and
  `extractFromTo({from, to})`.
* `LyricsDataController({required LyricsData lyricsData})` is a factory on an
  abstract class; build one per song and keep it in the `State` (create it in
  `initState`, not in `build`). Its whole public surface is:
  * `lyricsData` — the data it was built from.
  * `update(Duration time)` — move the playhead. Call this on every tick of
    whatever actually plays the audio; it is idempotent and handles seeking
    backwards as well as forwards.
  * `play({double speed = 1})` — self-driven playback from an internal
    stopwatch, ticking `update` every 10 ms. Use it only for demos/previews
    with no real audio; `speed` above 1 fast-forwards.
* There is **no public `pause()`, `stop()` or `dispose()`**: once `play()` has
  started, its loop runs until the widget tree is gone. For anything that must
  pause, seek or stop, drive the controller with `update(position)` from your
  audio player's position stream and never call `play()`.
* `LyricsDataPlayer({required LyricsDataController controller, required
  LyricsDataPlayerStyle style})` **must be given bounded constraints** — it uses
  `LayoutBuilder` + `ScrollablePositionedList` and computes its font size as
  `width * 0.05`. Inside a `ListView`/`Column`, wrap it in a `SizedBox(height:
  ...)` or an `Expanded`; an unbounded height throws.
* `LyricsDataPlayerStyle({required onTextStyle, required offTextStyle,
  textScaler = TextScaler.noScaling, scrollDuration = 300ms, lineCount})`:
  * `onTextStyle` / `offTextStyle` are the sung and not-yet-sung styles; any
    `fontSize` you set is **ignored** (it is derived from the width) — set
    `textScaler` instead.
  * `lineCount` fixes how many lines fill the height (each line gets
    `height / lineCount`); leave it null for natural line heights.
  * `scrollDuration` is the auto-scroll animation to the current line.
  * Start from `LyricsDataPlayerStyle.defaultLight` or `.defaultDark` (both are
    getters returning a fresh instance) and `copyWith(...)`.
* Anti-patterns: rebuilding the controller on every `build` (the scroll
  position and the per-part streams are lost); calling `play()` *and*
  `update()` on the same controller; putting `LyricsDataPlayer` directly in a
  scrollable without a height.
* The package has no tests of its own; `example/flp_example` is the reference
  app (`lib/play_screen.dart` shows the minimal screen). For a widget test,
  pump the player inside a `SizedBox` and call `controller.update(...)` with
  explicit durations rather than relying on `play()`.

## Examples

### A play screen driven by the controller's own clock

```dart
import 'package:festenao_lyrics_player/lyrics_player.dart';
import 'package:flutter/material.dart';

/// Enhanced LRC: per word timestamps inside each line.
const lrcDemo = '''
[00:00.00]
[00:00.04]<00:00.04> When <00:00.16> the <00:00.82> truth <00:01.29> is
[00:06.47]<00:07.67> And <00:07.94> all <00:08.36> the <00:08.63> joy
[00:19.48] The end
''';

/// Plays [lrc] on its own stopwatch (demo/preview only, no pause).
class PlayScreen extends StatefulWidget {
  /// Lyrics, LRC format.
  final String lrc;

  /// Constructor.
  const PlayScreen({super.key, this.lrc = lrcDemo});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late final LyricsDataController controller = LyricsDataController(
    lyricsData: parseLyricLrc(widget.lrc),
  );

  @override
  void initState() {
    super.initState();
    controller.play(speed: 1);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lyrics')),
    body: ListView(
      padding: const EdgeInsets.all(8),
      children: [
        SizedBox(
          height: 112,
          child: LyricsDataPlayer(
            controller: controller,
            style: LyricsDataPlayerStyle.defaultLight.copyWith(
              textScaler: const TextScaler.linear(0.9),
              lineCount: 2,
            ),
          ),
        ),
      ],
    ),
  );
}
```

### Synced to an external audio position (pause and seek work)

```dart
import 'dart:async';

import 'package:festenao_lyrics_player/lyrics_player.dart';
import 'package:flutter/material.dart';

/// Full screen lyrics following [positionStream] of an audio player.
class SyncedLyricsView extends StatefulWidget {
  /// Lyrics, LRC format.
  final String lrc;

  /// Current playback position of the audio player.
  final Stream<Duration> positionStream;

  /// Constructor.
  const SyncedLyricsView({
    super.key,
    required this.lrc,
    required this.positionStream,
  });

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  late final LyricsDataController controller = LyricsDataController(
    lyricsData: parseLyricLrc(widget.lrc),
  );
  StreamSubscription<Duration>? _subscription;

  @override
  void initState() {
    super.initState();
    // Never call play() here: update() is the seekable/pausable path.
    _subscription = widget.positionStream.listen(controller.update);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: LyricsDataPlayer(
      controller: controller,
      style: LyricsDataPlayerStyle.defaultDark.copyWith(
        lineCount: 5,
        scrollDuration: const Duration(milliseconds: 200),
      ),
    ),
  );
}
```

### Inspecting the parsed data, and a custom style

```dart
import 'package:festenao_lyrics_player/lyrics_player.dart';
import 'package:flutter/material.dart';

/// Parsed lyrics: title, duration and the plain text of each line.
List<String> lyricsSummary(String lrc) {
  var data = parseLyricLrc(lrc);
  return [
    '${data.title ?? '?'} - ${data.artist ?? '?'} (${data.duration})',
    for (var line in data.lines) '${line.time}: ${line.text}',
  ];
}

/// Only the chorus, re-serialized to LRC.
List<String> chorusLrc(LyricsData data) => data
    .extractFromTo(
      from: parseLyricDurationLrc('00:30.00'),
      to: parseLyricDurationLrc('01:00.00'),
    )
    .toLrcLines();

/// A style of our own (fontSize is ignored, use textScaler).
LyricsDataPlayerStyle karaokeStyle() => LyricsDataPlayerStyle(
  onTextStyle: const TextStyle(color: Colors.amber),
  offTextStyle: const TextStyle(color: Colors.white70),
  textScaler: const TextScaler.linear(1.2),
  lineCount: 3,
);
```

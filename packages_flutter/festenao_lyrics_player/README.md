# festenao_lyrics_player

Time synced lyrics for Flutter: an LRC string (plain or per word) is parsed
into a `LyricsData`, a `LyricsDataController` knows which line and word are
current at a given time, and the `LyricsDataPlayer` widget shows them in an
auto scrolling list, highlighting what has been sung.

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  festenao_lyrics_player:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_lyrics_player
```

```dart
import 'dart:async';

import 'package:festenao_lyrics_player/lyrics_player.dart';
import 'package:material_ui/material_ui.dart';

const lrc = '''
[00:00.00]<00:00.00>Hello <00:00.50>world
[00:02.00]Second line
''';

/// Lyrics following the position of an audio player.
class LyricsView extends StatefulWidget {
  final Stream<Duration> position;

  const LyricsView({super.key, required this.position});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  late final LyricsDataController controller;
  late final StreamSubscription<Duration> subscription;

  @override
  void initState() {
    super.initState();
    controller = LyricsDataController(lyricsData: parseLyricLrc(lrc));
    subscription = widget.position.listen(controller.update);
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 200,
    child: LyricsDataPlayer(
      controller: controller,
      style: LyricsDataPlayerStyle.defaultLight.copyWith(lineCount: 3),
    ),
  );
}
```

Pure Flutter: every platform (Android, iOS, web, Linux, macOS, Windows), no
plugin.

## What to know

- `controller.update(position)` is the way to follow real audio (pause and
  seek work). `controller.play(speed:)` runs a clock of its own, for demos
  and previews: it runs until `controller.pause()`, call it in
  `State.dispose`.
- `LyricsDataPlayer` needs a bounded height (a `SizedBox`, an `Expanded`):
  it is a scrollable list. The font size is 1/20 of its width, a `fontSize`
  in the styles is ignored: use `textScaler`.
- Build the controller once per song (in the `State`), not in `build`.
- `parseLyricLrc` and the model come from `tekaly_lyrics`, re-exported.
- `karaoke_player.dart` (`KaraokeLyricsView`, `SongbookLyricsView`) moved to
  `tekaly_lyrics_view` (`tekartikprj/music`); it is re-exported here,
  deprecated, until its users switch.

The `festenao-lyrics-player-widget` skill (`skills/`) has more examples;
`example/flp_example` is a demo app.

---
name: festenao-youtube-player-playlist
description: >-
  Use when a Flutter app plays a YouTube playlist (or a video) with its own
  controls and its own ordering: createYtPlayerBackend(options:),
  YtPlayerBackend (initialize, resolve, open, play, pause, seek, setMuted,
  setPlaybackRate, buildVideoView, completions, playback, onEntryMetadata,
  onPlaybackError, dispose), YtPlayerBackendOptions(showControls:),
  YtPlaybackState, YtResolvedPlaylist, YtResolveException, YtPlaylistEntry
  (displayTitle, thumbnailUri, mergedWith), parseYtSource / YtSource /
  YtVideoSource / YtPlaylistSource, and the playlist listing
  YoutubePlaylistPage.fetch / YoutubePlaylistListing / parseClockDuration, from
  package:festenao_youtube_player/yt_player.dart.
---

# Youtube playlist backend (festenao_youtube_player)

`yt_player.dart` is the low level half of the package: a platform backend that
knows how to play **one video at a time** and how to draw it into a box, plus
the link parsing and playlist listing that feed it. Ordering — next, previous,
shuffle, repeat — stays in the app, which is exactly why it behaves the same on
every platform.

## Guidelines

* Dependency (not on pub.dev, git only):

  ```yaml
  dependencies:
    festenao_youtube_player:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_youtube_player
  ```

  Desktop plays through mpv: `sudo apt install libmpv-dev mpv` (plus
  `ubuntu-restricted-extras libavcodec-extra` for the usual codecs). The web
  needs nothing extra. `initialize()` already calls
  `MediaKit.ensureInitialized()`, do not call it yourself.

* Import `package:festenao_youtube_player/yt_player.dart`. Never import
  `package:festenao_youtube_player/src/...`, and in particular never
  `yt_backend_io.dart`/`yt_backend_web.dart` directly — `createYtPlayerBackend`
  is a conditional export that picks the right one (and throws
  `UnsupportedError` where neither `dart:io` nor `dart:js_interop` exists).
* Life cycle, in this order: `var backend = createYtPlayerBackend(options:
  const YtPlayerBackendOptions(showControls: false));` →
  `await backend.initialize();` (once, before anything else) → `resolve` →
  `open` → `play`/`pause`/… → `await backend.dispose()`. The backend is
  unusable after `dispose()`; build a new one.
* `YtPlayerBackendOptions({bool showControls = false})`. The default `false` is
  what a playlist app wants: it draws its own controls, and it also puts a
  transparent layer over the web iframe so taps, focus and keys stay with
  Flutter. Set `true` only when you want youtube's/media_kit's own controls.
* `parseYtSource(String input)` returns a **sealed** `YtSource?`, so `switch`
  on it exhaustively: `YtVideoSource(videoId)` or
  `YtPlaylistSource(playlistId, startVideoId:, startIndex:)`. It understands
  `watch?v=`, `youtu.be/`, `/shorts/`, `/embed/`, `/live/`, `/v/`,
  `playlist?list=`, `music.youtube.com` and bare video (11 chars) or playlist
  ids, and returns `null` for anything else. A link with both `v=` and `list=`
  resolves to the **playlist**, starting on that video; youtube's 1 based
  `index=` is converted to a 0 based `startIndex`.
* `Future<YtResolvedPlaylist> resolve(YtSource source)` expands the source into
  `entries` (`List<YtPlaylistEntry>`), a `title` and a `startIndex` — it does
  not start playing. It throws `YtResolveException` (with a `message` meant for
  the user) when the playlist is private, empty or not embeddable; catch it.
* `Future<void> open(YtPlaylistEntry entry, {bool autoPlay = true})` loads one
  entry. Advancing is yours: listen to `completions` (a `Stream<void>`, one
  event each time the current video runs out) and `open` the next entry —
  that is where repeat/shuffle logic goes.
* `playback` is a `ValueListenable<YtPlaybackState>`: `position`, `duration`,
  `playing`, `buffering`, `muted`, `soundBlocked`, `aspectRatio`,
  `playbackRate`. Drive the ui from a `ValueListenableBuilder`, and size the
  video box with `playback.value.aspectRatio ?? 16 / 9` — `buildVideoView`
  fills whatever box it is given and does not letterbox.
* Controls: `play()`, `pause()`, `seek(Duration)`, `setMuted(bool)`,
  `setPlaybackRate(double)`. Rates are best effort: youtube's iframe only
  honours the ones it offers (0.25 to 2) and silently keeps the current one
  otherwise, so read back `playback.value.playbackRate` instead of assuming.
* Callbacks, set right after `initialize()`: `onEntryMetadata` fires when a
  title/author/duration arrives late (the web gets ids from the iframe long
  before titles from oembed) — merge it into your list with
  `entry.mergedWith(updated)`; `onPlaybackError` fires when playback fails
  *after* `open` returned.
* `YtPlaylistEntry({required String videoId, String? title, String? author,
  Duration? duration})` also gives `displayTitle` (title, else the id) and
  `thumbnailUri` (`i.ytimg.com/vi/<id>/mqdefault.jpg`) — use them instead of
  building the strings yourself.
* `YoutubePlaylistPage({http.Client? client})` reads a playlist off youtube's
  own page: `await page.fetch(playlistId, max: 200)` returns a
  `YoutubePlaylistListing(entries, title)`, and `page.close()` releases the
  client it owns (it does not close a client you passed in). It exists because
  youtube_explode_dart's playlist parser returns nothing since youtube moved to
  `lockupViewModel`; the io backend uses it internally, so you only need it to
  list a playlist without playing it. `parseClockDuration('3:55')` /
  `parseClockDuration('1:02:03')` turns those page strings into a `Duration?`.
* Known limits to design around: playlists are capped at 200 entries;
  generated mixes (`list=RD…`) usually cannot be listed and a
  `watch?v=…&list=RD…` link falls back to the single video; on the web autoplay
  with sound is blocked, so playback starts muted and unmuting may set
  `soundBlocked` (show an unmute affordance rather than fighting it); desktop
  falls back to the 360p muxed stream when youtube refuses the adaptive ones to
  mpv.
* Anti-patterns: calling `resolve`/`open` before `initialize()`; letting the
  platform player own the playlist (it does not — one video at a time is the
  contract); putting `buildVideoView` in an unbounded box; polling
  `playback.value` in a timer instead of listening; forgetting
  `await backend.dispose()` in `State.dispose` (it is async: `unawaited(...)`
  it).
* Testing: `parseYtSource`, `parseClockDuration` and the entry helpers are pure
  and unit testable with plain `flutter_test`. Anything that talks to youtube
  (the playlist page, the stream choice) is tagged `live` and skipped by
  default — run those with `flutter test --run-skipped --tags live`, and expect
  them to be the first thing that breaks when youtube changes.

## Examples

### A playlist player with its own next/previous

```dart
import 'dart:async';

import 'package:festenao_youtube_player/yt_player.dart';
import 'package:flutter/material.dart';

/// Plays whatever [link] expands to, one video at a time, and advances by
/// itself when a video ends.
class PlaylistPlayer extends StatefulWidget {
  /// A youtube link or a bare id.
  final String link;

  /// Constructor.
  const PlaylistPlayer({super.key, required this.link});

  @override
  State<PlaylistPlayer> createState() => _PlaylistPlayerState();
}

class _PlaylistPlayerState extends State<PlaylistPlayer> {
  // showControls: false, we draw our own.
  final _backend = createYtPlayerBackend(
    options: const YtPlayerBackendOptions(),
  );
  StreamSubscription<void>? _completions;
  var _entries = <YtPlaylistEntry>[];
  var _index = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    // Once, before anything else.
    await _backend.initialize();
    // Late arriving titles (the web gets ids first).
    _backend.onEntryMetadata = (entry) {
      var at = _entries.indexWhere((e) => e.videoId == entry.videoId);
      if (at >= 0 && mounted) {
        setState(() => _entries[at] = _entries[at].mergedWith(entry));
      }
    };
    _backend.onPlaybackError = (message) {
      if (mounted) setState(() => _error = message);
    };
    // One event per video that runs out: advancing is our job.
    _completions = _backend.completions.listen((_) => unawaited(next()));

    var source = parseYtSource(widget.link);
    if (source == null) {
      setState(() => _error = 'Not a youtube link');
      return;
    }
    try {
      var playlist = await _backend.resolve(source);
      if (!mounted) return;
      setState(() {
        _entries = playlist.entries;
        _index = playlist.startIndex;
      });
      await _backend.open(_entries[_index]);
    } on YtResolveException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Ordering lives here, so it behaves the same on every platform.
  Future<void> next() async {
    if (_entries.isEmpty) return;
    var index = (_index + 1) % _entries.length;
    setState(() => _index = index);
    await _backend.open(_entries[index]);
  }

  /// Previous video.
  Future<void> previous() async {
    if (_entries.isEmpty) return;
    var index = (_index - 1 + _entries.length) % _entries.length;
    setState(() => _index = index);
    await _backend.open(_entries[index]);
  }

  @override
  void dispose() {
    unawaited(_completions?.cancel());
    // Async, and the backend is dead afterwards.
    unawaited(_backend.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var error = _error;
    if (error != null) {
      return Scaffold(body: Center(child: Text(error)));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _entries.isEmpty ? 'Loading' : _entries[_index].displayTitle,
        ),
      ),
      body: ValueListenableBuilder<YtPlaybackState>(
        valueListenable: _backend.playback,
        builder: (context, playback, _) => Column(
          children: [
            // The view fills the box: we choose the ratio.
            AspectRatio(
              aspectRatio: playback.aspectRatio ?? 16 / 9,
              child: _backend.buildVideoView(context),
            ),
            if (playback.buffering) const LinearProgressIndicator(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: previous,
                  icon: const Icon(Icons.skip_previous),
                ),
                IconButton(
                  onPressed: () => playback.playing
                      ? _backend.pause()
                      : _backend.play(),
                  icon: Icon(
                    playback.playing ? Icons.pause : Icons.play_arrow,
                  ),
                ),
                IconButton(onPressed: next, icon: const Icon(Icons.skip_next)),
                IconButton(
                  // The web starts muted, and unmuting may be refused.
                  onPressed: () => _backend.setMuted(!playback.muted),
                  icon: Icon(
                    playback.muted ? Icons.volume_off : Icons.volume_up,
                  ),
                ),
              ],
            ),
            if (playback.soundBlocked)
              const Text('The browser blocked the sound, tap to unmute'),
            Text('${playback.position} / ${playback.duration}'),
          ],
        ),
      ),
    );
  }
}
```

### Parsing what the user pasted

```dart
import 'package:festenao_youtube_player/yt_player.dart';

/// YtSource is sealed: switch on it exhaustively.
String describe(String pasted) {
  var source = parseYtSource(pasted);
  return switch (source) {
    YtVideoSource(:var videoId) => 'one video $videoId',
    // A watch link carrying a list= lands here, with startVideoId set.
    YtPlaylistSource(:var playlistId, :var startVideoId, :var startIndex) =>
      'playlist $playlistId '
          '(start ${startVideoId ?? startIndex ?? 'at the beginning'})',
    null => 'not a youtube link',
  };
}

/// Only a playlist source is worth listing; a mix (list=RD...) usually is not.
String? playlistIdOf(String pasted) => switch (parseYtSource(pasted)) {
  YtPlaylistSource(:var playlistId) => playlistId,
  _ => null,
};
```

### Listing a playlist without playing it

```dart
import 'package:festenao_youtube_player/yt_player.dart';
import 'package:flutter/material.dart';

/// Reads the playlist page (up to 200 entries) and shows it.
/// Hits youtube for real, so keep it out of the default test run.
Future<List<YtPlaylistEntry>> listPlaylist(String playlistId) async {
  var page = YoutubePlaylistPage();
  try {
    var listing = await page.fetch(playlistId, max: 200);
    debugPrint('${listing.title}: ${listing.entries.length} entries');
    return listing.entries;
  } finally {
    // Closes the http client it created.
    page.close();
  }
}

/// A list tile per entry, with youtube's own thumbnail.
Widget entryTile(YtPlaylistEntry entry) => ListTile(
  leading: Image.network(entry.thumbnailUri.toString(), width: 80),
  // Falls back to the id while the title is unknown.
  title: Text(entry.displayTitle),
  subtitle: Text(entry.author ?? ''),
  trailing: Text(entry.duration?.toString() ?? ''),
);

/// The page's own '3:55' / '1:02:03' strings.
Duration? runtimeOf(String clock) => parseClockDuration(clock);
```

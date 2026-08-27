# festenao_youtube_player

Two youtube players, sharing one set of platform workarounds.

## Setup

```yaml
  festenao_youtube_player:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_youtube_player
```

## `player.dart` — one video, controls included

The simple one: hand it a video id, get a widget. The player draws its own
controls (youtube's on the web, media_kit's elsewhere).

```dart
final controller = FestenaoYoutubeController(
  options: FesteneaoYoutubeOptions(videoId: 'dQw4w9WgXcQ', autoPlay: true),
);
...
FestenaoYoutubePlayer(controller: controller);
```

`controller.stateStream` ticks position, duration, playback rate and a
[FestenaoYoutubePlayerStatus]; `play()`, `pause()`, `stop()` and `seekTo()`
drive it.

## `yt_player.dart` — a playlist backend, no ui

The low level one, for an app that draws its own controls and owns its own
playlist. It expands a link into a list of videos and then plays them one at a
time, so shuffle, repeat and next/previous behave identically on every
platform because they never reach the platform at all.

```dart
final backend = createYtPlayerBackend();
await backend.initialize();

final playlist = await backend.resolve(parseYtSource(link)!);
await backend.open(playlist.entries[playlist.startIndex]);
await backend.play();

// backend.playback  -> ValueListenable<YtPlaybackState>
// backend.completions -> Stream<void>, one event per video that runs out
// backend.buildVideoView(context) fills whatever box you give it
```

`resolve` takes a `YtSource` from `parseYtSource`, which understands
`watch?v=`, `youtu.be/`, `/shorts/`, `/embed/`, `/live/`, `playlist?list=`,
`music.youtube.com`, and bare video or playlist ids. A link carrying both a
`v=` and a `list=` opens the playlist and starts on that video, the way
youtube itself does.

Desktop needs mpv:

```
sudo apt install libmpv-dev mpv
sudo apt install ubuntu-restricted-extras libavcodec-extra
```

## How the backend works

- **Desktop / mobile** (`yt_backend_io.dart`) resolves the media urls with
  youtube_explode_dart and plays them with media_kit (mpv). It aims for an
  adaptive video stream plus a separate audio track, since muxed streams never
  go above 360p, but checks first that youtube will actually serve them the
  way mpv asks (see below) and drops back to the muxed stream when it will
  not.
- **Web** (`yt_backend_web.dart`) drives youtube's own iframe player, because a
  browser cannot reach youtube's pages or media urls across origins. The
  playlist is cued into the iframe once, read back out with `getPlaylist()`,
  and then played one video at a time. Titles come from youtube's oembed
  endpoint, which is the one youtube url a browser is allowed to read.

## Youtube being youtube

Two things the backend has to work around, both of which will need revisiting
whenever youtube changes again:

- **Playlist pages.** `YoutubePlaylistPage` reads playlist contents off the
  playlist page itself. youtube_explode_dart cannot: youtube moved the page to
  `lockupViewModel` entries and the package's parser returns nothing at all.
  Everything else the package does still works.
- **Adaptive streams.** mpv opens a url with an open ended `Range: bytes=0-`,
  and youtube now answers some adaptive streams with `403` unless the range is
  bounded. Muxed streams are still served either way. Nothing in the manifest
  says which is which, so the backend asks for the stream exactly the way mpv
  will before handing it over.

Both are covered by live tests, which are the ones that break first when
youtube moves. They talk to youtube for real, so they are skipped by the plain
`flutter test`:

```
flutter test --run-skipped --tags live
```

## Known limitations

- On the web, browsers block autoplay with sound until the page has earned it,
  so playback usually starts muted. Unmuting sometimes stops playback outright
  (the iframe needs a click of its own, which it never gets because flutter
  owns the pointer); the backend notices, goes back to muted, and raises
  `soundBlocked`.
- Playlists are capped at 200 entries.
- Desktop playback falls back to the 360p muxed stream whenever youtube
  refuses to serve the adaptive ones to mpv.
- Generated mixes (`list=RD…`) usually cannot be listed. A `watch?v=…&list=RD…`
  link falls back to playing just that video.

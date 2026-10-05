// A throwaway probe: what the web backend does when the browser refuses to
// autoplay with sound (run headless with --autoplay-policy=...), read from
// the console.
import 'dart:async';

import 'package:festenao_youtube_player/yt_player.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const ProbeApp());

class ProbeApp extends StatefulWidget {
  const ProbeApp({super.key});

  @override
  State<ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<ProbeApp> {
  final backend = createYtPlayerBackend();
  final started = DateTime.now();
  YtPlaybackState? last;
  var ready = false;

  void log(String message) {
    var ms = DateTime.now().difference(started).inMilliseconds;
    // ignore: avoid_print
    print('probe +${ms}ms $message');
  }

  @override
  void initState() {
    super.initState();
    backend.playback.addListener(() {
      var v = backend.playback.value;
      var l = last;
      if (l == null ||
          v.playing != l.playing ||
          v.muted != l.muted ||
          v.soundBlocked != l.soundBlocked ||
          v.buffering != l.buffering) {
        log(
          'playing=${v.playing} buffering=${v.buffering} muted=${v.muted} '
          'soundBlocked=${v.soundBlocked} position=${v.position}',
        );
      }
      last = v;
    });
    backend.onPlaybackError = (message) => log('error $message');
    unawaited(() async {
      await backend.initialize();
      setState(() => ready = true);
      await Future<void>.delayed(const Duration(seconds: 2));
      log('open 1');
      await backend.open(const YtPlaylistEntry(videoId: 'dQw4w9WgXcQ'));
      await Future<void>.delayed(const Duration(seconds: 12));
      log('open 2 (the sound tried again)');
      await backend.open(const YtPlaylistEntry(videoId: 'kJQP7kiw5Fk'));
      await Future<void>.delayed(const Duration(seconds: 12));
      log('unmute');
      await backend.setMuted(false);
      await Future<void>.delayed(const Duration(seconds: 8));
      log('done');
    }());
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 640,
          height: 360,
          child: ready ? backend.buildVideoView(context) : const SizedBox(),
        ),
      ),
    ),
  );
}

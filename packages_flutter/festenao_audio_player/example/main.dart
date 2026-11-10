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

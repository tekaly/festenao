import 'package:festenao_audio_player/player.dart';
import 'package:festenao_audio_player/src/import.dart';
import 'package:flutter/material.dart';

class AppAudioPlayerWidget extends StatefulWidget {
  final AppAudioPlayerSong? song;
  final AppAudioPlayer player;

  const AppAudioPlayerWidget({
    super.key,
    required this.player,
    required this.song,
  });

  @override
  State<AppAudioPlayerWidget> createState() => _AppAudioPlayerWidgetState();
}

class _AppAudioPlayerWidgetState extends State<AppAudioPlayerWidget> {
  AppAudioPlayer get player => widget.player;

  AppAudioPlayerSong? get song => widget.song;

  var _seeking = false;
  double? _seekValue;
  // ignore: unused_field
  var _seekingPlaying = false;

  double? get seekValue => _seeking ? _seekValue! : null;

  @override
  void initState() {
    // print('loading song $song');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // IconButton(onPressed: () {}, icon: Icon(Icons.skip_previous)),
        IconButton(
          onPressed: () async {
            await player.seek(Duration.zero);
          },
          icon: const Icon(Icons.skip_previous),
        ),

        IconButton(
          onPressed: () async {
            if (song == null) {
              await player.play();
            } else {
              await player.playSong(song!);
            }
          },
          iconSize: 64,
          icon: const Icon(Icons.play_arrow),
        ),
        IconButton(
          onPressed: () async {
            await player.pause();
          },
          iconSize: 32,
          icon: const Icon(Icons.pause),
        ),
        IconButton(
          onPressed: () async {
            await player.resume();
          },
          iconSize: 32,
          icon: const Icon(Icons.play_arrow_outlined),
        ),
        IconButton(
          onPressed: () async {
            await player.stop();
            await player.seek(Duration.zero);
          },
          iconSize: 32,
          icon: const Icon(Icons.stop),
        ),
        IconButton(
          onPressed: () async {
            var duration = await player.getDuration();
            if (duration != null) {
              await player.seek(duration);
            }
          },
          icon: const Icon(Icons.skip_next),
        ),
        StreamBuilder<Duration?>(
          builder: (context, snapshot) {
            var position = snapshot.data ?? Duration.zero;
            return Text(position.toString());
          },
          stream: player.positionStream,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StreamBuilder<AppAudioPlayerState>(
            builder: (context, snapshot) {
              return StreamBuilder<Duration?>(
                builder: (context, positionSnapshot) {
                  var duration = snapshot.data?.duration;
                  var position =
                      positionSnapshot.data ??
                      snapshot.data?.position ??
                      Duration.zero;
                  var value = 0.0;
                  if (duration != null && duration > Duration.zero) {
                    value = position.inMilliseconds / duration.inMilliseconds;
                  }
                  value = value.bounded(0, 1);
                  return Slider(
                    value: seekValue ?? value,
                    onChangeStart: (value) {
                      _seekingPlaying = snapshot.data?.playing ?? false;
                      setState(() {
                        _seeking = true;
                        _seekValue = value;
                      });
                    },
                    onChangeEnd: (value) async {
                      setState(() {
                        _seeking = false;
                        _seekValue = value;
                      });
                      if (duration != null) {
                        var position = Duration(
                          milliseconds:
                              (duration.inMilliseconds * value).toInt(),
                        );
                        await player.seek(position);
                        await player.resume();

                        /*
                        // Bug on linux it seems to restart playback
                        //if (_seekingPlaying) {
                        while (
                            player.currentPlayer?.stateValue.playing ?? true) {
                          await sleep(1);
                          await player.pause();
                        }
                        print('pausing');
                        await sleep(100);
                        await player.resume();*/
                        /*
                          await Future<void>.delayed(
                              Duration(milliseconds: 500));
                          await player.pause();*/
                        //}
                      }
                    },
                    onChanged: (double value) {
                      setState(() {
                        _seeking = true;
                        _seekValue = value;
                      });
                    },
                  );
                },
                stream: player.positionStream,
              );
            },
            stream: player.stateStream,
          ),
        ),
      ],
    );
  }
}

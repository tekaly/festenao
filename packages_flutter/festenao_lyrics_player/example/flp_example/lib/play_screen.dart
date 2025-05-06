import 'package:festenao_common_flutter/common_utils.dart';
import 'package:festenao_lyrics_player/lyrics_player.dart';
import 'package:flutter/material.dart';
import 'package:tekaly_lyrics/utils/lyrics_data_located.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

/// Demo1
var lrcDemo1 = '''
[00:00.00]
[00:00:04] <00:00.04> When <00:00.16> the <00:00.82> truth <00:01.29> is <00:01.63> found <00:03.09> to <00:03.37> be <00:05.92> lies 
[00:06.47] <00:07.67> And <00:07.94> all <00:08.36> the <00:08.63> joy <00:10.28> within <00:10.53> you <00:13.09> dies 
[00:13.34] <00:14.32> Don't <00:14.73> you <00:15.14> want <00:15.57> somebody <00:16.09> to <00:16.46> love
[00:16.47]
[00:19.48] The end
''';

class _PlayScreenState extends State<PlayScreen> {
  late LocatedLyricsData data;
  LyricsDataController? controllerOrNull;
  LyricsDataController get controller => controllerOrNull!;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    data = LocatedLyricsData(lyricsData: parseLyricLrc(lrcDemo1));
    sleep(0).then((_) {
      controllerOrNull?.play(speed: 10);
    });
  }

  @override
  Widget build(BuildContext context) {
    controllerOrNull ??= LyricsDataController(
      lyricsData: parseLyricLrc(lrcDemo1),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Festenao Lyrics Player')),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          SizedBox(
            height: 150,
            child: LyricsDataPlayer(
              controller: controller,
              style: LyricsDataPlayerStyle.defaultLight.copyWith(
                textScaler: TextScaler.linear(.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

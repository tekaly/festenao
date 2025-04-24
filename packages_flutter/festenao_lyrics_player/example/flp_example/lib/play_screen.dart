import 'package:flutter/material.dart';
import 'package:tekaly_lyrics/example/lyrics_example.dart';
import 'package:tekaly_lyrics/lyrics.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class LocatedLyricsDataWidget extends StatefulWidget {
  final LocatedLyricsData lyricsData;
  const LocatedLyricsDataWidget({super.key, required this.lyricsData});

  @override
  State<LocatedLyricsDataWidget> createState() =>
      _LocatedLyricsDataWidgetState();
}

class _LocatedLyricsDataWidgetState extends State<LocatedLyricsDataWidget> {
  LocatedLyricsData get lyricsData => widget.lyricsData;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [for (var line in lyricsData.lines) Text(line.text)],
    );
  }
}

class _PlayScreenState extends State<PlayScreen> {
  late LocatedLyricsData data;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    data = LocatedLyricsData(lyricsData: parseLyricLrc(lrcDemo1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Festenao Lyrics Player')),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          SizedBox(
            height: 300,
            child: LocatedLyricsDataWidget(lyricsData: data),
          ),
        ],
      ),
    );
  }
}

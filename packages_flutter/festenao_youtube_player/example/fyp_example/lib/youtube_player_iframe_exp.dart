import 'package:flutter/material.dart';

import 'package:youtube_player_iframe/youtube_player_iframe.dart';

///
class YoutubePlayerIframeExp extends StatefulWidget {
  ///
  const YoutubePlayerIframeExp({super.key});

  @override
  State<YoutubePlayerIframeExp> createState() => _YoutubePlayerIframeExpState();
}

class _YoutubePlayerIframeExpState extends State<YoutubePlayerIframeExp> {
  var controller = YoutubePlayerController.fromVideoId(
    videoId: 'gCRNEJxDJKM',
    params: const YoutubePlayerParams(
      showControls: true,
      showFullscreenButton: true,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Youtube Player Iframe Web Demo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    controller.playVideo();
                  },
                  icon: const Icon(Icons.play_circle),
                ),
                IconButton(
                  onPressed: () {
                    controller.pauseVideo();
                  },
                  icon: const Icon(Icons.pause_circle),
                ),
              ],
            ),

            SizedBox(
              height: 1000,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return YoutubePlayer(controller: controller);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:festenao_common_flutter/common_utils_widget.dart';
import 'package:festenao_youtube_player/player.dart';
import 'package:flutter/material.dart';

class FestenaoYoutubePlayerExp extends StatefulWidget {
  final String title;
  const FestenaoYoutubePlayerExp({super.key, required this.title});
  @override
  State<FestenaoYoutubePlayerExp> createState() =>
      _FestenaoYoutubePlayerExpState();
}

class _FestenaoYoutubePlayerExpState
    extends AutoDisposeBaseState<FestenaoYoutubePlayerExp> {
  late final _fController = audiAddDisposable(
    FestenaoYoutubeController(
      options: FesteneaoYoutubeOptions(videoId: videoId, autoPlay: true),
    ),
  );

  var videoId = 'NsJLhRGPv-M';
  @override
  void initState() {
    // Initialize the controller when the widget is created
    //  _controller = YoutubeWebPlayerController();
    // Add a listener to track changes in video playback position
    //_controller?.addListener(_positionListener);
    // Call the superclass method to ensure proper initialization
    super.initState();
  }

  @override
  void dispose() {
    // Remove the listener when the widget is disposed to avoid memory leaks
    //_controller?.removeListener(_positionListener);
    // Call the superclass method to ensure proper disposal
    super.dispose();
  }

  // Listener method that prints the current video playback position to the console
  // ignore: unused_element
  void _positionListener() {
    //print("position: ${_controller!.position}");
  }

  // Build method to create the widget's UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Create a Scaffold to provide a basic material design layout
      appBar: AppBar(
        // Set the title of the app
        title: Text(widget.title),
      ),
      body: ListView(
        // Create a ListView for scrolling through multiple widgets
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          SizedBox(
            height: 300,
            // Use YoutubeWebPlayer to display the video
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: FestenaoYoutubePlayer(
                controller: _fController,
                //controller: _controller,
                //videoId: "NsJLhRGPv-M", // Specify the video ID to play
              ),
            ),
          ),
          // Play button to start video playback
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {
                  muiSnack(context, 'paused');
                  _fController.pause();
                },
                icon: const Icon(Icons.pause_circle, size: 50),
              ),
              IconButton(
                onPressed: () {
                  muiSnack(context, 'playing');
                  _fController.play();
                  // Call the play method on the controller to start playback
                  //_controller?.play.call();
                },
                icon: const Icon(Icons.play_circle, size: 50),
              ),
            ],
          ),
          StreamBuilder(
            stream: _fController.stateStream,
            builder: (_, snapshot) {
              var state = snapshot.data;
              var status = state?.status ?? FestenaoYoutubePlayerStatus.unknown;
              var durationMs = state?.duration.inMilliseconds ?? 0;
              var positionMs = state?.position.inMilliseconds ?? 0;
              var positionDouble = (durationMs == 0)
                  ? 0
                  : (positionMs / durationMs).bounded(0, 1);
              if (durationMs == 0) {
                return const SizedBox();
              }
              return Column(
                children: [
                  LinearProgressIndicator(value: positionDouble.toDouble()),
                  Slider(
                    value: positionDouble.toDouble(),
                    onChangeEnd: (value) {
                      // Seek to the new position when the slider is released
                      _fController.seekTo(
                        Duration(milliseconds: (durationMs * value).toInt()),
                        allowSeekAhead: true,
                      );
                    },
                    onChanged: (value) {
                      // Seek to the new position when the slider is moved
                      _fController.seekTo(
                        Duration(milliseconds: (durationMs * value).toInt()),
                      );
                    },
                  ),
                  ListTile(
                    title: Text(status.toString().split('.').last),
                    subtitle: Text('${state?.position} / ${state?.duration}'),
                  ),
                ],
              );
            },
          ), // Pause button to stop video playback
          /*
          Row(
            // Align buttons to the center of the row
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Button to seek back 5 seconds in the video
              TextButton(
                onPressed: () {
                  _controller!.seekTo(
                    _controller!.position - Duration(seconds: 5),
                  );
                },
                child: Icon(Icons.skip_previous, size: 50),
              ),
              // Button to seek forward 5 seconds in the video
              TextButton(
                onPressed: () {
                  _controller!.seekTo(
                    _controller!.position + Duration(seconds: 5),
                  );
                },
                child: Icon(Icons.skip_next, size: 50),
              ),
            ],
          ),
          // Button to set playback speed to normal (1x)
          TextButton(
            onPressed: () {
              _controller?.setPlaybackSpeed(1);
            },
            child: Text("SetPlaybackSpeed 1"),
          ),
          // Button to set playback speed to half (0.5x)
          TextButton(
            onPressed: () {
              _controller?.setPlaybackSpeed(0.5);
            },
            child: Text("SetPlaybackSpeed 0.5"),
          ),*/
        ],
      ),
    );
  }
}

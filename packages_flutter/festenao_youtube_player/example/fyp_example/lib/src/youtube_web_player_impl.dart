import 'package:festenao_common_flutter/common_utils_flutter.dart';
import 'package:festenao_youtube_player/player.dart';
import 'package:flutter/material.dart';
import 'package:youtube_web_player/youtube_web_player.dart';

/// Festenao Youtube Web Player controller
class FestenaoYoutubeWebPlayerController extends FestenaoYoutubeControllerBase {
  @override
  final FesteneaoYoutubeOptions options;

  /// Implementation controller
  late final webController = audiAddSelf(
    YoutubeWebPlayerController(),
    (self) => self.dispose(),
  );

  /// Constructor
  FestenaoYoutubeWebPlayerController({required this.options}) {
    // print('New FestenaoYoutubeWebPlayerController');
  }

  /// Any second call will crash

  // Add your controller properties and methods here

  @override
  void play() {
    // devPrint("play ${webController.position}");
    webController.play();
    // Logic to play the video
  }

  @override
  void pause() {
    // devPrint("pause ${webController.position}");
    webController.pause();
    // Logic to pause the video
  }

  @override
  void stop() {
    webController.pause();
    // Logic to stop the video
  }

  /// True when ready
  Future<void> get ready async {
    // Logic to prepare the player
  }

  @override
  void seekTo(Duration duration, {bool allowSeekAhead = false}) {
    // TODO: implement seekTo
  }
}

/// Festenao Youtube Web Player
class FestenaoYoutubeWebPlayer extends StatefulWidget {
  /// controller
  final FestenaoYoutubeController controller;

  /// Constructor for FestenaoYoutubeWebPlayer.
  const FestenaoYoutubeWebPlayer({super.key, required this.controller});

  @override
  State<FestenaoYoutubeWebPlayer> createState() =>
      _FestenaoYoutubeWebPlayerState();
}

class _FestenaoYoutubeWebPlayerState
    extends AutoDisposeBaseState<FestenaoYoutubeWebPlayer> {
  FestenaoYoutubeWebPlayerController get _controller =>
      widget.controller as FestenaoYoutubeWebPlayerController;

  // Declare a controller for interacting with the YouTube video player
  YoutubeWebPlayerController get _implController => _controller.webController;

  @override
  void initState() {
    // Add a listener to track changes in video playback position
    _implController.addListener(_positionListener);
    // Call the superclass method to ensure proper initialization
    super.initState();
  }

  @override
  void dispose() {
    // Remove the listener when the widget is disposed to avoid memory leaks
    _implController.removeListener(_positionListener);
    // Call the superclass method to ensure proper disposal
    super.dispose();
  }

  // Listener method that prints the current video playback position to the console
  void _positionListener() {
    // print("position: ${_implController.position}");
  }

  // Build method to create the widget's UI
  @override
  Widget build(BuildContext context) {
    return ListView(
      // Create a ListView for scrolling through multiple widgets
      padding: const EdgeInsets.all(8),
      children: <Widget>[
        SizedBox(
          height: 300,
          // Use YoutubeWebPlayer to display the video
          child: YoutubeWebPlayer(
            controller: _implController,
            videoId: 'NsJLhRGPv-M', // Specify the video ID to play
          ),
        ),
        // Play button to start video playback
        TextButton(
          onPressed: () => _implController.play(),
          child: const Icon(Icons.play_circle, size: 50),
        ),
        // Pause button to stop video playback
        TextButton(
          onPressed: () {
            _controller.pause();
          },
          child: const Icon(Icons.pause_circle, size: 50),
        ),
        Row(
          // Align buttons to the center of the row
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Button to seek back 5 seconds in the video
            TextButton(
              onPressed: () {
                _implController.seekTo(
                  _implController.position - const Duration(seconds: 5),
                );
              },
              child: const Icon(Icons.skip_previous, size: 50),
            ),
            // Button to seek forward 5 seconds in the video
            TextButton(
              onPressed: () {
                _implController.seekTo(
                  _implController.position + const Duration(seconds: 5),
                );
              },
              child: const Icon(Icons.skip_next, size: 50),
            ),
          ],
        ),
        // Button to set playback speed to normal (1x)
        TextButton(
          onPressed: () {
            _implController.setPlaybackSpeed(1);
          },
          child: const Text('SetPlaybackSpeed 1'),
        ),
        // Button to set playback speed to half (0.5x)
        TextButton(
          onPressed: () {
            _implController.setPlaybackSpeed(0.5);
          },
          child: const Text('SetPlaybackSpeed 0.5'),
        ),
      ],
    );
  }
}

class _FestenaoYoutubeWebPlayerService extends FestenaoYoutubePlayerService {
  @override
  FestenaoYoutubeController newController({
    required FesteneaoYoutubeOptions options,
  }) {
    return FestenaoYoutubeWebPlayerController(options: options);
  }

  @override
  Widget newPlayer({Key? key, required FestenaoYoutubeController controller}) {
    return FestenaoYoutubeWebPlayer(key: key, controller: controller);
  }
}

FestenaoYoutubePlayerService festenaoYoutubeWebPlayerService =
    _FestenaoYoutubeWebPlayerService();

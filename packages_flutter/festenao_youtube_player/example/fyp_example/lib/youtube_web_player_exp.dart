// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:youtube_web_player/youtube_web_player.dart';

class YoutubeWebPlayerExp extends StatefulWidget {
  const YoutubeWebPlayerExp({super.key});

  @override
  State<YoutubeWebPlayerExp> createState() => _YoutubeWebPlayerExpState();
}

class _YoutubeWebPlayerExpState extends State<YoutubeWebPlayerExp> {
  // Declare a controller for interacting with the YouTube video player
  YoutubeWebPlayerController? _controller;

  @override
  void initState() {
    // Initialize the controller when the widget is created
    _controller = YoutubeWebPlayerController();
    // Add a listener to track changes in video playback position
    _controller?.addListener(_positionListener);
    // Call the superclass method to ensure proper initialization
    super.initState();
  }

  @override
  void dispose() {
    // Remove the listener when the widget is disposed to avoid memory leaks
    _controller?.removeListener(_positionListener);
    // Call the superclass method to ensure proper disposal
    super.dispose();
  }

  // Listener method that prints the current video playback position to the console
  void _positionListener() {
    print('position: ${_controller!.position}');
  }

  // Build method to create the widget's UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Create a Scaffold to provide a basic material design layout
      appBar: AppBar(
        // Set the title of the app
        title: const Text('youtube_web_player Demo'),
      ),
      body: ListView(
        // Create a ListView for scrolling through multiple widgets
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          SizedBox(
            height: 300,
            // Use YoutubeWebPlayer to display the video
            child: YoutubeWebPlayer(
              controller: _controller,
              videoId: 'NsJLhRGPv-M', // Specify the video ID to play
            ),
          ),
          // Play button to start video playback
          TextButton(
            onPressed: () => _controller?.play.call(),
            child: const Icon(Icons.play_circle, size: 50),
          ),
          // Pause button to stop video playback
          TextButton(
            onPressed: () => _controller?.pause.call(),
            child: const Icon(Icons.pause_circle, size: 50),
          ),
          Row(
            // Align buttons to the center of the row
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Button to seek back 5 seconds in the video
              TextButton(
                onPressed: () {
                  _controller!.seekTo(
                    _controller!.position - const Duration(seconds: 5),
                  );
                },
                child: const Icon(Icons.skip_previous, size: 50),
              ),
              // Button to seek forward 5 seconds in the video
              TextButton(
                onPressed: () {
                  _controller!.seekTo(
                    _controller!.position + const Duration(seconds: 5),
                  );
                },
                child: const Icon(Icons.skip_next, size: 50),
              ),
            ],
          ),
          // Button to set playback speed to normal (1x)
          TextButton(
            onPressed: () {
              _controller?.setPlaybackSpeed(1);
            },
            child: const Text('SetPlaybackSpeed 1'),
          ),
          // Button to set playback speed to half (0.5x)
          TextButton(
            onPressed: () {
              _controller?.setPlaybackSpeed(0.5);
            },
            child: const Text('SetPlaybackSpeed 0.5'),
          ),
        ],
      ),
    );
  }
}

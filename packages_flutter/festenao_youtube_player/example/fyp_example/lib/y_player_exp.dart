// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:y_player/y_player.dart';

class YPlayerExp extends StatefulWidget {
  const YPlayerExp({super.key});

  @override
  State<YPlayerExp> createState() => _YPlayerExpState();
}

class _YPlayerExpState extends State<YPlayerExp> {
  YPlayerController? _controller;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YPlayer Example')),
      body: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  _controller!.play();
                },
                icon: const Icon(Icons.play_circle),
              ),
              IconButton(
                onPressed: () {
                  _controller!.pause();
                },
                icon: const Icon(Icons.pause_circle),
              ),
            ],
          ),
          YPlayer(
            youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            onStateChanged: (status) {
              print('Player Status: $status');
            },
            onProgressChanged: (position, duration) {
              print('Progress: ${position.inSeconds}/${duration.inSeconds}');
            },
            onControllerReady: (controller) {
              print('Controller is ready!');
              _controller = controller;
            },
          ),
        ],
      ),
    );
  }
}

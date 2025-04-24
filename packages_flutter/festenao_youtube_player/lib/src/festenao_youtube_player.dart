import 'package:festenao_youtube_player/player.dart';
import 'package:flutter/material.dart';

/// Festenao Youtube Player
class FestenaoYoutubePlayer extends StatelessWidget {
  /// The controller for the Youtube player.
  final FestenaoYoutubeController controller;

  /// Constructor for FestenaoYoutubePlayer.
  const FestenaoYoutubePlayer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return festenaoYoutubePlayerService.newPlayer(
      key: key,
      controller: controller,
    );
  }
}

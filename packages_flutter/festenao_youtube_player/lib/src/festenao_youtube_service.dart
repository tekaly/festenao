import 'package:festenao_youtube_player/player.dart';
import 'package:festenao_youtube_player/src/impl_backend.dart';
import 'package:flutter/widgets.dart';

/// The service that builds the controller and the widget of
/// [FestenaoYoutubePlayer]. Replace it to plug in another implementation.
var festenaoYoutubePlayerService = festenaoYoutubePlayerServiceDefault;

/// One implementation for every platform, on top of `yt_player.dart`: youtube's
/// iframe player on the web, media_kit (mpv) everywhere else.
final festenaoYoutubePlayerServiceDefault = festenaoYoutubeBackendPlayerService;

/// Festenao Youtube Player Service
abstract class FestenaoYoutubePlayerService {
  /// New controller
  FestenaoYoutubeController newController({
    required FesteneaoYoutubeOptions options,
  });

  /// New player
  Widget newPlayer({Key? key, required FestenaoYoutubeController controller});
}

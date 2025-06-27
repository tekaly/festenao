import 'package:festenao_youtube_player/player.dart';
import 'package:festenao_youtube_player/src/impl_y_player.dart';
import 'package:festenao_youtube_player/src/impl_youtube_player_iframe.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Using youtube_player_iframe for web and y_player for non-web
/// youtube_web_player controls don't work
var festenaoYoutubePlayerService = festenaoYoutubePlayerServiceDefault;

/// Using youtube_player_iframe for web and y_player for non-web
/// youtube_web_player controls don't work
final festenaoYoutubePlayerServiceDefault = kIsWeb
    ? festenaoYoutubePlayerIframeService
    : festenaoYoutubeYPlayerService;

/// Festenao Youtube Player Service
abstract class FestenaoYoutubePlayerService {
  /// New controller
  FestenaoYoutubeController newController({
    required FesteneaoYoutubeOptions options,
  });

  /// New player
  Widget newPlayer({Key? key, required FestenaoYoutubeController controller});
}

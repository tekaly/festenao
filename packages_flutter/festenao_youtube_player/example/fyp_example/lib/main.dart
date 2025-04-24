import 'dart:io';

import 'package:festenao_common_flutter/common_utils_widget.dart';
import 'package:festenao_youtube_player/player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fyp_example/festenao_youtube_player_exp.dart';
import 'package:fyp_example/y_player_exp.dart';
import 'package:fyp_example/youtube_player_iframe_exp.dart';

import 'package:fyp_example/youtube_web_player_exp.dart';
import 'package:y_player/y_player.dart';

import 'src/youtube_web_player_impl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  YPlayerInitializer.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        //

        //

        //
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Builder(
        builder: (context) {
          return muiScreenWidget('Youtube', () async {
            muiItem('Festenao youtube player', () {
              festenaoYoutubePlayerService =
                  festenaoYoutubePlayerServiceDefault;
              ContentNavigator.pushBuilder<void>(
                context,
                builder:
                    (context) => const FestenaoYoutubePlayerExp(
                      title: 'Festenao youtube player',
                    ),
              );
            });

            muiItem('y_player (non web)', () {
              ContentNavigator.pushBuilder<void>(
                context,
                builder: (context) => const YPlayerExp(),
              );
            });
            muiItem('youtube_web_player (web)', () {
              ContentNavigator.pushBuilder<void>(
                context,
                builder: (context) => const YoutubeWebPlayerExp(),
              );
            });

            if (!(!kIsWeb && Platform.isLinux)) {
              muiItem(
                'Festenao youtube player using Legacy youtube_web_player',
                () {
                  festenaoYoutubePlayerService =
                      festenaoYoutubeWebPlayerService;
                  ContentNavigator.pushBuilder<void>(
                    context,
                    builder:
                        (context) => const FestenaoYoutubePlayerExp(
                          title: 'Legacy youtube_web_player',
                        ),
                  );
                },
              );
              muiItem('youtube_player_iframe (web only?)', () {
                ContentNavigator.pushBuilder<void>(
                  context,
                  builder: (context) => const YoutubePlayerIframeExp(),
                );
              });

              muiItem('youtube_player_iframe (non web)', () {
                ContentNavigator.pushBuilder<void>(
                  context,
                  builder: (context) => const YoutubePlayerIframeExp(),
                );
              });
            }
          });
        },
      ),
    );
  }
}

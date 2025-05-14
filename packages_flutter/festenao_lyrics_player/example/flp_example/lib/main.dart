import 'package:festenao_common_flutter/common_utils_widget.dart';
import 'package:festenao_common_flutter/dev_menu_flutter.dart';
import 'package:flp_example/play_screen.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  await mainTestMenu();
}

Future<void> mainTestMenu() async {
  WidgetsFlutterBinding.ensureInitialized();

  Future<void> play(String lrc, {double? speed}) async {
    ContentNavigator.pushBuilder<void>(
      buildContext!,
      builder: (context) => PlayScreen(lrc: lrc, speed: speed),
    );
  }

  mainMenuFlutter(() {
    enter(() async {
      //      await karReady;
    });

    item('quick play', () async {
      await play(lrcDemo1, speed: 6.0);
    });
    item('play 2 lines', () async {
      await play('''
      [00:00.00]Zero<00:01.00>One
      [00:02.00]Two<00:03.00>Three  
      ''');
    });
  }, showConsole: true);
}

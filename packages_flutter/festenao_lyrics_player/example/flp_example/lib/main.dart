import 'package:flp_example/play_screen.dart';
import 'package:flutter/material.dart';
import 'package:festenao_common_flutter/common_utils_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(),
      home: muiScreenWidget('Festenao lyrics Player', () async {
        muiItem('Player', () {
          ContentNavigator.pushBuilder<void>(
            muiBuildContext,
            builder: (context) => PlayScreen(),
          );
        });
        // });
      }),
    );
  }
}

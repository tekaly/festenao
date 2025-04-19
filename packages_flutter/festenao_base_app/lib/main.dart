// ignore_for_file: public_member_api_docs

import 'package:festenao_base_app/form/src/screen/debug_screen.dart';
import 'package:festenao_base_app/import/ui.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_theme/theme.dart';
import 'package:flutter/material.dart';

late AppFlavorContext appFlavorContext;

var initialized = () async {
  return;
  /*
  await initFormBloc(
    databaseFactory: await getDatabaseFactory(
      packageName: 'com.tekartik.festenao_base_app',
    ),
    appFlavorContext: appFlavorContext,
  );*/
}();

void main() {
  appFlavorContext = AppFlavorContext.testLocal;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',

      theme: poppinsThemeData1(),
      home: const DemoHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<DemoHomePage> createState() => DemoHomePageState();
}

class DemoHomePageState extends State<DemoHomePage> {
  @override
  Widget build(BuildContext context) {
    return muiScreenWidget('Menu', () {
      muiItem('Form', () async {
        await initialized;
        if (context.mounted) {
          await goToUserDebugScreen(context);
        }
      });
    });
  }
}

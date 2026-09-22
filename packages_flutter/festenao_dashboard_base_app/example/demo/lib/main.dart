/// The festenao explorers demo, everything in memory.
///
/// It opens the firestore, file system, sdb and sembast explorers on content
/// built at startup: nothing is written to the disk, and modifications are
/// lost on restart, which is what makes it safe to edit anything in it.
///
/// ```sh
/// flutter run -d linux     # or -d chrome
/// ```
library;

import 'package:flutter/material.dart';

import 'src/demo_data.dart';
import 'src/demo_home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FestenaoExplorersDemoApp());
}

/// The demo app.
class FestenaoExplorersDemoApp extends StatelessWidget {
  /// Const constructor.
  const FestenaoExplorersDemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Festenao explorers demo',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
    home: const DemoLoadingPage(),
  );
}

/// Builds the demo content, then shows the menu.
class DemoLoadingPage extends StatefulWidget {
  /// Const constructor.
  const DemoLoadingPage({super.key});

  @override
  State<DemoLoadingPage> createState() => _DemoLoadingPageState();
}

class _DemoLoadingPageState extends State<DemoLoadingPage> {
  late final Future<DemoData> _loading = DemoData.create();

  @override
  Widget build(BuildContext context) => FutureBuilder<DemoData>(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(body: Center(child: Text('${snapshot.error}')));
      }
      var data = snapshot.data;
      if (data == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return DemoHomePage(data: data);
    },
  );
}

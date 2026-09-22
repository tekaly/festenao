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
import 'src/demo_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FestenaoExplorersDemoApp());
}

/// The demo app, which holds the theme the home page swaps.
class FestenaoExplorersDemoApp extends StatefulWidget {
  /// The theme it starts on.
  final int initialThemeIndex;

  /// Const constructor.
  const FestenaoExplorersDemoApp({super.key, this.initialThemeIndex = 0});

  @override
  State<FestenaoExplorersDemoApp> createState() =>
      _FestenaoExplorersDemoAppState();
}

class _FestenaoExplorersDemoAppState extends State<FestenaoExplorersDemoApp> {
  late final List<DemoTheme> _themes = demoThemes();
  late int _themeIndex = widget.initialThemeIndex;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Festenao explorers demo',
    debugShowCheckedModeBanner: false,
    theme: _themes[_themeIndex].build(),
    home: DemoLoadingPage(
      themes: _themes,
      themeIndex: _themeIndex,
      onThemeChanged: (index) => setState(() {
        _themeIndex = index;
      }),
    ),
  );
}

/// Builds the demo content, then shows the menu.
class DemoLoadingPage extends StatefulWidget {
  /// The themes the home page offers.
  final List<DemoTheme> themes;

  /// Which one is on.
  final int themeIndex;

  /// Picks another one.
  final ValueChanged<int>? onThemeChanged;

  /// Const constructor.
  const DemoLoadingPage({
    super.key,
    this.themes = const [],
    this.themeIndex = 0,
    this.onThemeChanged,
  });

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
      return DemoHomePage(
        data: data,
        themes: widget.themes,
        themeIndex: widget.themeIndex,
        onThemeChanged: widget.onThemeChanged,
      );
    },
  );
}

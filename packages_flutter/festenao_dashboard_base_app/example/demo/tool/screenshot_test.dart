/// Renders every screen of the demo and writes it as a png.
///
/// It goes through the flutter test pipeline rather than a running window:
/// the widgets are the real ones and so is the rendering, but nothing needs a
/// display, and each screen is reached on purpose rather than by driving a
/// window.
///
/// ```sh
/// flutter test tool/screenshot_test.dart
/// ```
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:festenao_common_flutter/firestore_explorer_flutter.dart';
import 'package:festenao_dashboard_app_demo/src/demo_data.dart';
import 'package:festenao_dashboard_app_demo/src/demo_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the pngs land.
const screenshotDirectory = '.local/screenshots_1';

/// The window the screens are rendered in.
const screenshotSize = Size(1100, 800);

final _rootKey = GlobalKey();

var _index = 0;

/// Where the flutter sdk keeps the fonts a running app is given.
///
/// The test harness draws with a font that shows every glyph as a box, so the
/// real ones are loaded here: the text reads as text, and the icons as icons.
String get _flutterFontsPath {
  var executable = Platform.resolvedExecutable;
  var root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    // dart is `<flutter>/bin/cache/dart-sdk/bin/dart`.
    var directory = File(executable).parent.parent.parent.parent.parent;
    root = directory.path;
  }
  return '$root/bin/cache/artifacts/material_fonts';
}

/// Loads the real text and icon fonts.
Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    var loader = FontLoader(family);
    var loaded = false;
    for (var path in paths) {
      var file = File(path);
      if (file.existsSync()) {
        loader.addFont(
          file.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
        );
        loaded = true;
      }
    }
    if (loaded) {
      await loader.load();
    } else {
      // ignore: avoid_print
      print('no font for $family, it will draw as boxes');
    }
  }

  var fonts = _flutterFontsPath;
  // Under `Roboto`, the family the material text styles ask for, so every
  // default style picks it up.
  await load('Roboto', [
    '$fonts/Roboto-Regular.ttf',
    '$fonts/Roboto-Medium.ttf',
    '$fonts/Roboto-Bold.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  ]);
  await load('MaterialIcons', ['$fonts/MaterialIcons-Regular.otf']);
  await load('monospace', [
    '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
  ]);
}

/// Lets the really asynchronous backends settle, pumping between real delays.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Writes what is on screen as `NN_name.png`.
Future<void> _shot(WidgetTester tester, String name) async {
  await _settle(tester);
  var boundary =
      tester.renderObject(find.byKey(_rootKey)) as RenderRepaintBoundary;
  var image = await boundary.toImage(pixelRatio: 2);
  var bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  var file = File(
    '$screenshotDirectory/${(++_index).toString().padLeft(2, '0')}_$name.png',
  );
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote ${file.path}');
}

/// Taps [finder] and lets things settle.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await _settle(tester);
}

/// Goes back one screen.
Future<void> _back(WidgetTester tester) async {
  await tester.pageBack();
  await _settle(tester);
}

void main() {
  testWidgets('every screen', (tester) async {
    await tester.runAsync(() async {
      await _loadFonts();
      await tester.binding.setSurfaceSize(screenshotSize);
      var data = await DemoData.create();
      await tester.pumpWidget(
        RepaintBoundary(
          key: _rootKey,
          child: MaterialApp(
            title: 'Festenao explorers demo',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            ),
            home: DemoHomePage(data: data),
          ),
        ),
      );
      await _shot(tester, 'main_menu');

      // ---- firestore ----
      await _tap(tester, find.text('Firestore explorer'));
      await _shot(tester, 'firestore_collections');

      await _tap(tester, find.text('user'));
      await _shot(tester, 'firestore_documents');

      await _tap(tester, find.text('alice'));
      await _shot(tester, 'firestore_document_editor');

      // A row menu, showing what a value offers.
      await _tap(
        tester,
        find.descendant(
          of: find
              .ancestor(of: find.text('joinedAt'), matching: find.byType(Row))
              .first,
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await _shot(tester, 'firestore_value_menu');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
      await _back(tester);
      await _back(tester);

      // The settings document holds every firestore type.
      await _tap(tester, find.text('settings'));
      await _tap(tester, find.text('main'));
      await _shot(tester, 'firestore_every_type');
      await _back(tester);
      await _back(tester);

      // The backup dialog.
      await _tap(
        tester,
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.backup_outlined),
        ),
      );
      await _shot(tester, 'firestore_backup_formats');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
      await _back(tester);

      // ---- file system ----
      await _tap(tester, find.text('File system explorer'));
      await _shot(tester, 'file_system_listing');

      await _tap(tester, find.text('config.json'));
      await _shot(tester, 'json_editor');
      await _back(tester);

      await _tap(tester, find.text('settings.yaml'));
      await _shot(tester, 'yaml_editor');
      await _back(tester);

      await _tap(tester, find.text('notes.txt'));
      await _shot(tester, 'text_editor');
      await _back(tester);

      await _tap(tester, find.text('picture.bin'));
      await _shot(tester, 'hex_editor');
      await _back(tester);

      // What the + menu creates.
      await _tap(tester, find.byIcon(Icons.add));
      await _shot(tester, 'file_system_new_menu');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);
      await _back(tester);

      // ---- sdb ----
      await _tap(tester, find.text('Sdb explorer'));
      await _shot(tester, 'sdb_database_list');

      await _tap(tester, find.text('sdb_demo.db'));
      await _shot(tester, 'sdb_stores');

      await _tap(tester, find.text('note'));
      await _shot(tester, 'sdb_records');

      await _tap(tester, find.text('first'));
      await _shot(tester, 'sdb_record_editor');
      await _back(tester);
      await _back(tester);
      await _back(tester);
      await _back(tester);

      // ---- sembast ----
      await _tap(tester, find.text('Sembast explorer'));
      await _shot(tester, 'sembast_database_list');

      await _tap(tester, find.text('sembast_demo.db'));
      await _shot(tester, 'sembast_stores');

      await _tap(tester, find.text('settings'));
      await _tap(tester, find.text('main'));
      await _shot(tester, 'sembast_record_editor');
      await _back(tester);
      await _back(tester);
      await _back(tester);
      await _back(tester);

      // ---- every database together ----
      await _tap(tester, find.text('Every database'));
      await _shot(tester, 'every_database');
      await _back(tester);

      // ---- editing a value in memory ----
      await _tap(tester, find.text('Edit an object in memory'));
      await _shot(tester, 'edit_object_in_memory');

      // The type selector, on the count field.
      await _tap(
        tester,
        find.descendant(
          of: find
              .ancestor(of: find.text('count'), matching: find.byType(Row))
              .first,
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await _tap(tester, find.text('Change type'));
      await _shot(tester, 'type_selector');
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);

      await tester.binding.setSurfaceSize(null);
    });
  });
}

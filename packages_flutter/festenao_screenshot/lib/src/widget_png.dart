import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'screenshot_fonts.dart';

final _key = GlobalKey();

/// Declares the test [description] writing pngs of widgets with [body]
/// ([writeWidgetPng], [writeWebIcons]: the icons of an app drawn from its
/// logo, so that the icons and the app never differ): [body] runs in real
/// async with the fonts loaded ([loadScreenshotFonts]), the test view is
/// reset after.
void runWidgetPngs(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await loadScreenshotFonts();
      await body(tester);
    });
  });
}

/// Renders [child], laid out at [logicalSize], to the png files [paths],
/// [width] pixels wide (the height in proportion).
///
/// [child] sits on a transparent [Material] (the text of a logo has no
/// yellow underline) in a [MaterialApp] of [theme], or in the app [app]
/// builds around its `home` (a locale, the localizations), on a surface
/// larger than the image.
Future<void> writeWidgetPng(
  WidgetTester tester,
  List<String> paths, {
  required Widget child,
  required Size logicalSize,
  required int width,
  ThemeData? theme,
  Widget Function(Widget home)? app,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = logicalSize + const Offset(200, 200);
  var home = Material(
    type: MaterialType.transparency,
    child: Center(
      child: RepaintBoundary(
        key: _key,
        child: SizedBox.fromSize(size: logicalSize, child: child),
      ),
    ),
  );
  await tester.pumpWidget(
    app?.call(home) ??
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: home,
        ),
  );
  await tester.pump();
  var boundary = tester.renderObject(find.byKey(_key)) as RenderRepaintBoundary;
  var image = await boundary.toImage(pixelRatio: width / logicalSize.width);
  var bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  for (var path in paths) {
    await File(path).parent.create(recursive: true);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    stdout.writeln('wrote $path (${image.width} × ${image.height})');
  }
  image.dispose();
}

/// The maskable icon of a logo: [color] to the edges, the [symbol] built
/// for the width of the icon in the safe zone (the inner 80 %).
class MaskableIcon extends StatelessWidget {
  /// The background, to the edges.
  final Color color;

  /// Builds the symbol for the icon [width].
  final Widget Function(double width) symbol;

  /// A maskable icon of [color], [symbol] in the middle.
  const MaskableIcon({super.key, required this.color, required this.symbol});

  /// The [icon] in [iconColor] (white), half the width of the icon, on
  /// [color].
  MaskableIcon.icon(
    IconData icon, {
    super.key,
    required this.color,
    Color iconColor = const Color(0xFFFFFFFF),
  }) : symbol = ((width) => Icon(icon, color: iconColor, size: width * 0.5));

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Container(
      color: color,
      alignment: Alignment.center,
      child: symbol(constraints.maxWidth),
    ),
  );
}

/// Writes the web icons of an app in [webDirectory] (`web`):
/// `icons/Icon-192.png` and `icons/Icon-512.png` from [logo],
/// `icons/Icon-maskable-192.png` and `icons/Icon-maskable-512.png` from
/// [maskable] (a [MaskableIcon]), `favicon.png` (64 pixels) from [logo],
/// also written to [faviconCopies] (a site next to the app).
///
/// Both are laid out at [logicalSize] (128 by 128), in [theme] or [app] as
/// in [writeWidgetPng].
Future<void> writeWebIcons(
  WidgetTester tester, {
  required Widget logo,
  required Widget maskable,
  Size logicalSize = const Size(128, 128),
  String webDirectory = 'web',
  List<String> faviconCopies = const [],
  ThemeData? theme,
  Widget Function(Widget home)? app,
}) async {
  Future<void> write(List<String> paths, Widget child, int width) =>
      writeWidgetPng(
        tester,
        paths,
        child: child,
        logicalSize: logicalSize,
        width: width,
        theme: theme,
        app: app,
      );
  for (var width in [192, 512]) {
    await write(['$webDirectory/icons/Icon-$width.png'], logo, width);
    await write(
      ['$webDirectory/icons/Icon-maskable-$width.png'],
      maskable,
      width,
    );
  }
  await write(['$webDirectory/favicon.png', ...faviconCopies], logo, 64);
}

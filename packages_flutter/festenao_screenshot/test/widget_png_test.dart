import 'dart:io';
import 'dart:typed_data';

import 'package:festenao_screenshot/festenao_screenshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The width and height of a png.
(int, int) _pngSize(File file) {
  var data = ByteData.sublistView(file.readAsBytesSync());
  return (data.getUint32(16), data.getUint32(20));
}

final _directory = Directory.systemTemp.createTempSync('festenao_widget_png');

void main() {
  tearDownAll(() => _directory.deleteSync(recursive: true));

  runWidgetPngs('web icons', (tester) async {
    var web = '${_directory.path}/web';
    var copy = '${_directory.path}/site/favicon.png';
    await writeWebIcons(
      tester,
      logo: const ColoredBox(color: Colors.blue, child: Text('Ab')),
      maskable: MaskableIcon.icon(Icons.home, color: Colors.blue),
      webDirectory: web,
      faviconCopies: [copy],
    );
    expect(_pngSize(File('$web/icons/Icon-192.png')), (192, 192));
    expect(_pngSize(File('$web/icons/Icon-512.png')), (512, 512));
    expect(_pngSize(File('$web/icons/Icon-maskable-192.png')), (192, 192));
    expect(_pngSize(File('$web/icons/Icon-maskable-512.png')), (512, 512));
    expect(_pngSize(File('$web/favicon.png')), (64, 64));
    expect(
      File(copy).readAsBytesSync(),
      File('$web/favicon.png').readAsBytesSync(),
    );
  });

  runWidgetPngs('a share card, its height in proportion', (tester) async {
    var path = '${_directory.path}/og.png';
    await writeWidgetPng(
      tester,
      [path],
      child: const ColoredBox(color: Colors.white),
      logicalSize: const Size(600, 315),
      width: 1200,
      app: (home) => MaterialApp(home: home),
    );
    expect(_pngSize(File(path)), (1200, 630));
  });
}

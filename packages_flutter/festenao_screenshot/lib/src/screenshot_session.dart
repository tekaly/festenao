import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show BackButton;

import 'screenshot_fonts.dart';

/// The names of a comma separated filter (`track_meal,person_view`), as
/// passed with `--dart-define`: empty when the value is empty.
Set<String> screenshotNames(String value) => value
    .split(',')
    .map((name) => name.trim())
    .where((name) => name.isNotEmpty)
    .toSet();

/// A session of screenshots: opens widgets at a window size, waits for the
/// asynchronous backends, writes what is on screen as pngs.
///
/// Every call runs inside `tester.runAsync` (see [runScreenshots]): the
/// databases, streams and timers run on real time, frames are pumped by
/// hand.
///
/// [shot] numbers the files, per directory and prefix:
/// `[<prefix>_]NN_<name>.png`; [shotNamed] writes a file name as given.
class ScreenshotSession {
  /// The tester.
  final WidgetTester tester;

  /// Where the pngs land by default.
  final Directory directory;

  /// The ratio of the pngs to the logical pixels.
  final double pixelRatio;

  /// The device pixel ratio the screens see (`MediaQuery`).
  final double devicePixelRatio;

  /// When not empty, only the shots with one of these names are written:
  /// the name, the file name, or `<prefix>_<name>`.
  final Set<String> only;

  /// The default number of settling rounds of [settle].
  final int settleRounds;

  /// The key of the boundary [wrap] puts around the app, the area shot.
  final rootKey = GlobalKey();

  final _indexes = <String, int>{};
  var _runs = 0;

  /// The pngs written so far.
  final files = <File>[];

  /// The errors the screens reported (an overflow for instance), by file
  /// name.
  final errors = <String, String>{};

  /// A session writing into [directory].
  ScreenshotSession(
    this.tester, {
    required this.directory,
    this.pixelRatio = 2,
    this.devicePixelRatio = 1,
    this.only = const {},
    this.settleRounds = 20,
  });

  /// [app] in the boundary the shots capture, for a test pumping the app
  /// itself.
  Widget wrap(Widget app) => RepaintBoundary(key: rootKey, child: app);

  /// Replaces the screen with [widget] (a new element tree each time) in a
  /// window of [size] logical pixels when given, then waits.
  Future<void> open(Widget widget, {Size? size, int? settleRounds}) async {
    if (size != null) {
      await setSize(size);
    }
    await tester.pumpWidget(
      wrap(KeyedSubtree(key: ValueKey(++_runs), child: widget)),
    );
    await settle(rounds: settleRounds);
  }

  /// Resizes the window to [size] logical pixels, keeping the current screen.
  Future<void> setSize(Size size) async {
    await tester.binding.setSurfaceSize(size);
    // What the screens see (MediaQuery).
    tester.view.devicePixelRatio = devicePixelRatio;
    tester.view.physicalSize = size * devicePixelRatio;
    await tester.pump();
  }

  /// Lets the real asynchronous work (databases, streams) run and the frames
  /// build: alternates pumps of [pump] and real delays of [delay], [rounds]
  /// times ([settleRounds] by default).
  Future<void> settle({
    int? rounds,
    Duration pump = const Duration(milliseconds: 50),
    Duration delay = const Duration(milliseconds: 10),
  }) async {
    for (var i = 0; i < (rounds ?? settleRounds); i++) {
      await tester.pump(pump);
      await Future<void>.delayed(delay);
    }
  }

  /// Settles until [finder] finds something; throws after [rounds].
  Future<void> waitFor(Finder finder, {int rounds = 100}) async {
    for (var i = 0; i < rounds; i++) {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
      await settle(rounds: 1);
    }
    throw StateError('not found after $rounds rounds: $finder');
  }

  /// Taps the first match of [finder] (waiting for it) then settles.
  Future<void> tap(Finder finder, {int? settleRounds}) async {
    await waitFor(finder);
    await tester.ensureVisible(finder.first);
    await tester.pump();
    await tester.tap(finder.first);
    await settle(rounds: settleRounds);
  }

  /// Taps the first widget showing [text].
  Future<void> tapText(String text, {int? settleRounds}) =>
      tap(find.text(text), settleRounds: settleRounds);

  /// Taps the button with the [tooltip].
  Future<void> tapTooltip(String tooltip, {int? settleRounds}) =>
      tap(find.byTooltip(tooltip), settleRounds: settleRounds);

  /// Goes back (the back button of the app bar, or the navigator).
  ///
  /// The back button is the one of material_ui, what the festenao apps
  /// build; the navigator fallback only finds an English "Back" tooltip.
  Future<void> back({int? settleRounds}) async {
    var backButton = find.byType(BackButton);
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton.first);
    } else {
      await tester.pageBack();
    }
    await settle(rounds: settleRounds);
  }

  String _counterKey(Directory directory, String? prefix) =>
      '${directory.path}|${prefix ?? ''}';

  String _fileName(String name, String? prefix, int index) =>
      [?prefix, index.toString().padLeft(2, '0'), name].join('_');

  /// The file name the next [shot] of [name] gets.
  String nextFileName(String name, {String? prefix, Directory? directory}) {
    var key = _counterKey(directory ?? this.directory, prefix);
    return _fileName(name, prefix, (_indexes[key] ?? 0) + 1);
  }

  /// Whether a shot named [fileName] (or [name]) passes [only].
  bool wants(String fileName, {String? name, String? prefix}) =>
      only.isEmpty ||
      only.contains(fileName) ||
      (name != null &&
          (only.contains(name) ||
              (prefix != null && only.contains('${prefix}_$name'))));

  /// Whether the next [shot] of [name] is written (see [only]), to skip the
  /// navigation leading to it otherwise. When it is not, call [skip] to keep
  /// the numbering of the others.
  bool wantsNext(String name, {String? prefix, Directory? directory}) => wants(
    nextFileName(name, prefix: prefix, directory: directory),
    name: name,
    prefix: prefix,
  );

  /// Counts the next [shot] of [prefix] without writing it.
  void skip({String? prefix, Directory? directory}) {
    var key = _counterKey(directory ?? this.directory, prefix);
    _indexes[key] = (_indexes[key] ?? 0) + 1;
  }

  /// Restarts the numbering of [prefix] (at 01).
  void resetIndex({String? prefix, Directory? directory}) {
    _indexes.remove(_counterKey(directory ?? this.directory, prefix));
  }

  /// Writes what is on screen as `[<prefix>_]NN_<name>.png` in [directory]
  /// ([ScreenshotSession.directory] by default), NN counting the shots of
  /// that directory and prefix; nothing when [only] filters it out (the
  /// number is still counted). Returns the file written.
  Future<File?> shot(
    String name, {
    String? prefix,
    Directory? directory,
    int? settleRounds,
  }) async {
    directory ??= this.directory;
    var key = _counterKey(directory, prefix);
    var index = _indexes[key] = (_indexes[key] ?? 0) + 1;
    var fileName = _fileName(name, prefix, index);
    if (!wants(fileName, name: name, prefix: prefix)) {
      return null;
    }
    return _write(directory, fileName, settleRounds: settleRounds);
  }

  /// Writes what is on screen as `<fileName>.png`, unnumbered, unless [only]
  /// filters it out.
  Future<File?> shotNamed(
    String fileName, {
    Directory? directory,
    int? settleRounds,
  }) async {
    if (!wants(fileName)) {
      return null;
    }
    return _write(
      directory ?? this.directory,
      fileName,
      settleRounds: settleRounds,
    );
  }

  Future<File> _write(
    Directory directory,
    String fileName, {
    int? settleRounds,
  }) async {
    await settle(rounds: settleRounds);
    var exception = tester.takeException();
    if (exception != null) {
      errors[fileName] = '$exception';
    }
    patchFontFallbacks(tester);
    // One frame, to lay the patched text out and paint it, no time passing.
    await tester.pump();
    var boundary =
        tester.renderObject(find.byKey(rootKey)) as RenderRepaintBoundary;
    var image = await boundary.toImage(pixelRatio: pixelRatio);
    var bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    var file = File('${directory.path}/$fileName.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    files.add(file);
    stdout.writeln('wrote ${file.path}');
    return file;
  }

  /// Unmounts the screen and lets it end.
  Future<void> close() async {
    await tester.pumpWidget(const SizedBox());
    await settle(rounds: 10);
  }
}

void _clearPngs(Directory directory) {
  if (directory.existsSync()) {
    for (var file in directory.listSync()) {
      if (file is File && file.path.endsWith('.png')) {
        file.deleteSync();
      }
    }
  }
}

/// Declares the screenshot test [description]: [body] runs in real async
/// with the fonts loaded ([loadScreenshotFonts]), the shadows drawn and no
/// debug banner, on a [ScreenshotSession] writing into [directory].
///
/// [createSession] builds a session of its own (a subclass adding the
/// folders of a repository for instance) instead of the default one.
///
/// The previous pngs of [directory] (and of [clear]) are removed first
/// unless [only] filters the shots or [clearPngs] is false (a harness with
/// its own filter); the errors the screens reported are listed at the end.
void runScreenshots(
  String description,
  Future<void> Function(ScreenshotSession session) body, {
  required Directory directory,
  List<Directory> clear = const [],
  bool clearPngs = true,
  double pixelRatio = 2,
  double devicePixelRatio = 1,
  Set<String> only = const {},
  int settleRounds = 20,
  Duration timeout = const Duration(minutes: 5),
  ScreenshotSession Function(WidgetTester tester)? createSession,
}) {
  testWidgets(description, (tester) async {
    // No DEBUG ribbon, whatever MaterialApp the app builds.
    WidgetsApp.debugAllowBannerOverride = false;
    addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
    await tester.runAsync(() async {
      await loadScreenshotFonts();
      var session =
          createSession?.call(tester) ??
          ScreenshotSession(
            tester,
            directory: directory,
            pixelRatio: pixelRatio,
            devicePixelRatio: devicePixelRatio,
            only: only,
            settleRounds: settleRounds,
          );
      if (clearPngs && only.isEmpty) {
        for (var directory in [directory, ...clear]) {
          _clearPngs(directory);
        }
      }
      // The test binding disables the shadows (every elevated widget gets
      // a hard black outline instead); it checks they are disabled again
      // at the end of the test.
      debugDisableShadows = false;
      try {
        await body(session);
      } finally {
        debugDisableShadows = true;
        await session.close();
        await tester.binding.setSurfaceSize(null);
        tester.view.reset();
      }
      stdout.writeln('$description: ${session.files.length} screenshots');
      if (session.errors.isNotEmpty) {
        stdout.writeln('errors reported by the screens:');
        session.errors.forEach((file, error) {
          stdout.writeln('  $file: $error');
        });
      }
    });
  }, timeout: Timeout(timeout));
}

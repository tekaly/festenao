import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A phone, in logical pixels.
const screenshotPhoneSize = Size(400, 860);

/// A desktop window, in logical pixels.
const screenshotDesktopSize = Size(1200, 800);

String _two(int value) => value.toString().padLeft(2, '0');

/// The folder of a harness run: [path] when not empty (a `--dart-define`
/// override), `.local/<yyyy-MM-dd>-screenshots` otherwise (git ignored),
/// dated [now] (today by default).
Directory screenshotDatedDirectory({String path = '', DateTime? now}) {
  if (path.isNotEmpty) {
    return Directory(path);
  }
  now ??= DateTime.now();
  return Directory(
    '.local/${now.year}-${_two(now.month)}-${_two(now.day)}-screenshots',
  );
}

/// Runs [body] as on a desktop: the theme platform is macOS (the compact
/// density a theme reads when the app builds it), restored after.
///
/// Open the app inside [body]: the theme is built then.
Future<T> runAsScreenshotDesktop<T>(Future<T> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  try {
    return await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

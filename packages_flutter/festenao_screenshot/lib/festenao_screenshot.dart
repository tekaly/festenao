/// Screenshots of Flutter apps in `flutter test`: the widgets, the router and
/// the in memory backends are the real ones, nothing needs a display.
///
/// - [loadScreenshotFonts]: the real text and icon fonts (the test harness
///   draws every glyph as a box), the festenao_theme families included;
/// - [patchFontFallbacks]: the font fallbacks of a real app;
/// - [ScreenshotSession]: opens screens at a window size, waits for the
///   asynchronous backends, writes numbered pngs;
/// - [runScreenshots]: declares the test around a session;
/// - [screenshotNames]: the names of a `--dart-define` filter;
/// - [screenshotDatedDirectory], [screenshotPhoneSize],
///   [screenshotDesktopSize] and [runAsScreenshotDesktop]: the folder, the
///   sizes and the desktop density of an app harness.
library;

export 'src/screenshot_fonts.dart'
    show loadScreenshotFonts, patchFontFallbacks, screenshotPackageRoot;
export 'src/screenshot_layout.dart'
    show
        screenshotPhoneSize,
        screenshotDesktopSize,
        screenshotDatedDirectory,
        runAsScreenshotDesktop;
export 'src/screenshot_session.dart'
    show ScreenshotSession, runScreenshots, screenshotNames;

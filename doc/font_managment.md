# Font management: sharing fonts between apps

Draft, 2026-10-10, from the note:

> - How to share fonts between apps, one dart or flutter package per font?
> - Goal is to simplify having poppins theme and some mono font available
>   easily (just adding the package)

Everything below was checked on Flutter 3.47.6 (§9). Facts that were only
read in the Flutter sources say so.

## 0. In short

1. **Keep the bare family names** (`'Poppins'`, `'JetBrains Mono'`), as
   decided. A family declared by a package can only be reached as
   `packages/<package>/<family>`, and that prefix leaks into every bare
   family merged under it (§2.5). The `package:` route is a trap.
2. **Register the bare names at runtime.** The package ships the font files
   as plain assets and exposes `loadFestenaoFonts()`: one `FontLoader` per
   family. Weights and italics are read from the files, and the text renders
   exactly like a family declared in the pubspec, on the VM and on the web
   (verified, §2.4). An app adds the package and calls one function before
   `runApp`. Its pubspec needs no `fonts:` block.
3. **One pure Dart package per font family** (`tekartik_font_poppins`,
   `tekartik_font_jetbrains_mono`, later Inter). Each holds the files, the
   OFL as its `LICENSE` and a const descriptor. Flutter bundles the assets of
   a pure Dart dependency (verified, §2.2), and Dart tools can read the same
   files. A single generic Flutter loader serves them all, and festenao_theme
   depends on the two packages.
4. **Stop declaring the fonts under `fonts:` in festenao_theme now.** On the
   web, every declared family is downloaded before the first frame, yet
   almost nothing names `packages/festenao_theme/...`. That costs 1.64 MB
   (0.77 MB gzipped) at startup in every app depending on festenao_theme.
   Apps that also declare Poppins themselves download each Poppins file
   twice (§1.1).
5. **Ship only the weights the themes use, subset to Latin + Latin
   Extended.** Five Poppins files go from 806 KB to 130 KB, four JetBrains
   Mono files from 838 KB to 294 KB (box drawing and arrows kept), §6.

Phase 1 (§7) touches festenao_theme only, needs no new package, and fixes
the seven apps that ask for Poppins but draw Roboto.

**Status (2026-10-10).** Phase 1 done locally (committed, not pushed):

- festenao_theme declares the font files as assets and has
  `loadFestenaoFonts()` (`package:festenao_theme/fonts.dart`, also exported
  by `theme.dart` and `design.dart`; `test/fonts_test.dart`).
  `poppinsExtraBoldFont` (800) is an `extra:`, since a second `FontLoader`
  of the same family adds its weights (verified on the VM and the web).
- `festenaoAdminAppInit` loads the fonts, so every app going through it
  (admin, dashboards, orga) gets them. So do the base app, the dashboard
  demo and the theme gallery. The screenshot harness no longer loads the
  packaged names.
- Every app of the census calls it (directly or through that init), and the
  pubspec font blocks are gone. Left out: one app about to be retired, and
  one finished event app in a client repository.
- A release web build of an app calling it has only `MaterialIcons` in its
  `FontManifest.json`, and draws Poppins (400 to 800) and JetBrains Mono.
- Push festenao first: the apps need the new festenao_theme. A package that
  ran its tests before may keep a stale `build/unit_test_assets` without the
  new assets; delete it.

## 1. Today

festenao_theme holds:

- `lib/fonts/poppins/`: the 18 Poppins files (3.0 MB in the repo; only the
  declared ones are bundled) and `OFL.txt`;
- `lib/fonts/jetbrains_mono/`: four JetBrains Mono NL files (400 to 700)
  and `OFL.txt`;
- the constants `poppinsFontFamily = 'Poppins'` and
  `jetBrainsMonoFontFamily = 'JetBrains Mono'`, re-exported as
  `festenaoPoppinsFontFamily` and `festenaoMonospaceFontFamily`, plus
  `addPoppinsLicense()` and `addJetBrainsMonoLicense()`;
- a `fonts:` section declaring five Poppins files (400, italic, 500, 600,
  700) and the four JetBrains Mono files. Flutter registers them as
  `packages/festenao_theme/Poppins` and
  `packages/festenao_theme/JetBrains Mono` (§2.1).

The themes use the bare names. A bare name only resolves when the app
declares the family itself, and the README says so: *"Apps declare the
`Poppins` and `JetBrains Mono` fonts in their own pubspec"*. That is about
20 lines of pubspec per app.

Roboto follows the same pattern: `tekartik_app_roboto`
(tekartik/app_flutter_utils.dart) is a pure Dart package that only holds
the files, and each app declares what it uses
(`packages/tekartik_app_roboto/fonts/...`).

Census of the app checkouts that depend on festenao_theme (2026-10-10; the
app repos are private and the per-app list is kept apart):

| Group | Apps | What is drawn |
|-------|------|---------------|
| Declare the bare families in their own pubspec | 20 (13 of them demo apps) + 2 examples | Poppins; on the web the files are downloaded twice (§1.1) |
| Name the packaged family (`package: 'festenao_theme'`) | 2 | Poppins, exposed to the prefix leak (§2.5) |
| Use the poppins theme and declare nothing | 7 | **Roboto** (the platform default), with no warning |

### 1.1 What it costs on the web

Before the first frame, the web engine downloads every family listed in
`FontManifest.json`, whether the app uses it or not (engine
`initialization.dart`: `_downloadAssetFonts` is awaited together with the
renderer). Font bytes downloaded at startup by the buzzerelio web build,
which declares both families:

| Family | Files | Bytes |
|--------|-------|-------|
| `Poppins` (declared by the app, with 800) | 6 | 959 KB |
| `JetBrains Mono` (declared by the app) | 4 | 838 KB |
| `packages/festenao_theme/Poppins` | 5 | 806 KB |
| `packages/festenao_theme/JetBrains Mono` | 4 | 838 KB |
| Total, icons included | 21 | 3.46 MB |

Every web app depending on festenao_theme downloads the packaged half
(1.64 MB, 0.77 MB gzipped), including apps that use neither font. Every APK
and IPA bundles it too. One file can also be bundled twice: the app
declares it as `packages/festenao_theme/fonts/...` and the package as
`lib/fonts/...`, and those are two different asset keys (§2.3).

## 2. How Flutter resolves a family

1. **A package cannot register a bare family name.** flutter_tools
   (`asset.dart`, `_parsePackageFonts`) renames every family declared by a
   dependency to `packages/<package>/<family>`. Only the app's own pubspec
   registers bare names.
2. **A pure Dart package can carry fonts and assets.** flutter_tools reads
   the `flutter:` section of every transitive non-dev dependency, whether or
   not that dependency depends on Flutter. In the experiment, a package
   without a `flutter` dependency that declared `flutter: fonts:` showed up
   as `packages/font_poppins/Poppins` in the app's `FontManifest.json`, and
   another one's `flutter: assets:` were bundled.
3. **Asset keys depend on how the path is written.** In a dependency's
   pubspec, `lib/fonts/x.ttf` gets the key `packages/<pkg>/lib/fonts/x.ttf`.
   The self-prefixed form `packages/<pkg>/fonts/x.ttf` gets
   `packages/<pkg>/fonts/x.ttf`, which is also the key an app uses when it
   declares that file. If the package and the app use different forms, the
   file is bundled twice.
4. **`FontLoader` registers a bare family at runtime** from any bytes, for
   example `rootBundle.load('packages/<pkg>/fonts/Poppins-Regular.ttf')`.
   It takes no weight or style descriptor: the engine reads them from the
   files. Width of the text "Festival iiii MMMM" at 20 px:

   | Style | Family from the manifest (`packages/font_poppins/Poppins`) | `Poppins` registered by `FontLoader` |
   |-------|------|------|
   | 400 | 174.0 | 174.0 |
   | 700 | 186.0 | 186.0 |
   | italic | | 175.3 (the italic file) |
   | 500, no Medium file loaded | | 174.0 (nearest: Regular) |
   | 900, no Black file loaded | | 186.0 (nearest: Bold) |

   A release web build (CanvasKit, run in headless Chrome) gives the same
   numbers. Before the load, the bare family drew Roboto (167.6). The three
   files loaded in 18 ms from a local server. When a load completes, dart:ui
   sends a `fontsChange` message and the framework lays the text out again
   (`PaintingBinding.systemFonts`; read in the sources).
5. **The package prefix leaks.** A `TextStyle(package:)` keeps its package
   in a private field. `merge` passes `other._package`, and `copyWith` falls
   back to `package ?? _package` (`text_style.dart`), so any family that
   names no package inherits the theme's package. Under
   `ThemeData(fontFamily: 'Poppins', package: 'font_poppins')`:

   | Code | Family used |
   |------|-------------|
   | `Text('x')` | `packages/font_poppins/Poppins` ✓ |
   | `Text('x', style: TextStyle(fontFamily: 'monospace'))` | `packages/font_poppins/monospace` ✗ (no such family: platform default) |
   | `Text('x', style: TextStyle(fontFamily: 'JetBrains Mono'))` | `packages/font_poppins/JetBrains Mono` ✗ |
   | `style.copyWith(fontFamily: style.fontFamily)` | `packages/font_poppins/packages/font_poppins/Poppins` ✗ |
   | `style.copyWith(fontFamilyFallback: ['Noto'])` | fallback `packages/font_poppins/Noto` ✗ |
   | merging `TextStyle(fontFamily: 'JetBrains Mono', package: 'font_mono')` | `packages/font_mono/JetBrains Mono` ✓ |

   With packaged families, every family anywhere in the app must name its
   package, forever. The bare `'monospace'` styles in festenao_common_flutter
   (log viewer, credentials screen) would silently lose their font, and the
   screenshot harness already hit the doubled prefix (d49bee0). This is the
   technical reason to keep the bare names.
6. **`flutter test` loads no app font**, whatever the pubspec says. Every
   family draws FlutterTest squares (width 360.0 above) until a `FontLoader`
   runs. Widget tests are unaffected by the choice below, as long as nothing
   loads fonts implicitly.
7. **Web glyph fallback.** A glyph missing from every app font is drawn
   from Noto fonts fetched at runtime from `https://fonts.gstatic.com/s/`
   (engine configuration `fontFallbackBaseUrl`, which can be overridden;
   read in the sources). Native platforms fall back to system fonts. This
   matters for subsetting (§6).
8. **Licenses come for free.** flutter_tools copies the `LICENSE` (or
   `NOTICES`) file at the root of every dependency into the app's NOTICES
   (`license_collector.dart`; read in the sources). A font package whose
   `LICENSE` is the OFL needs no `addPoppinsLicense()`.

## 3. Solutions

### A. Each app declares the fonts (today)

The package holds the files, and each app copies the `fonts:` block.

- Pros: standard, synchronous, nothing to call.
- Cons: about 20 lines per app, and easy to forget: seven apps draw Roboto
  and nobody noticed. Easy to get subtly wrong: two key forms (§2.3),
  weight lists drifting away from the theme's. On the web, every declared
  family is downloaded at startup.

### B. Packaged family (`package:`)

This is how Flutter documents using a font from a package:
`ThemeData(fontFamily: 'Poppins', package: 'festenao_theme')`. The app
pubspec needs nothing.

- Pros: just add the package; synchronous.
- Cons: the prefix leak (§2.5) silently breaks every bare family used under
  the theme: monospace in the explorers, the mono labels of the kit,
  fallbacks. `copyWith(fontFamily: style.fontFamily)` doubles the prefix.
  The family constant stops being a plain name.
- **Rejected.** It also breaks the rule already in place: the family
  constants stay bare.

### C. Runtime registration under the bare name (recommended)

The package declares the font files as plain `assets:` (self-prefixed keys,
§2.3) and exposes an async loader (§5). The app awaits it before `runApp`,
or the festenao runners do it.

- Pros:
  - bare names and nothing in the app pubspec, just one call;
  - same rendering as a declared family, native and web (§2.4);
  - a font is downloaded only by the apps that load it: on the web, plain
    assets are fetched on demand, unlike manifest fonts;
  - widget tests are unchanged, and the screenshot harness calls the same
    loader.
- Cons:
  - Async: until the load completes, text uses the default font. Awaited
    before `runApp`, it costs one round of requests on the web, which the
    manifest fonts also cost today, since they block the first frame too.
    Start the load early and await it after the Firebase init, so the two
    overlap.
  - On native, `FontLoader` reads every file it is given at startup
    (about 800 KB for five Poppins files, 130 KB once subset), including
    weights that are never drawn.
  - Forgetting the call draws Roboto, as with A. Mitigation: the festenao
    runners call it, and maybe `FestenaoThemeController.load()` too (§8).
    A one-time `debugPrint` when a festenao theme is built before the fonts
    were loaded would point to the fix.

Variant: the theme builders start the load themselves, without awaiting it,
so the app needs no call at all. The first frame then uses the default font
and the text is laid out again when the load completes (§2.4). But it hides
an async side effect inside pure functions, and widget tests would start
drawing real fonts, so their text sizes would change. Not recommended.

### D. Tooling around A

A generator writes the `fonts:` block of the families an app needs
(`dart run festenao_theme:fonts`), and a CI test reads the built
`FontManifest.json`. That cures the forgetting but keeps the duplication
and the 20 lines. Only worth it if C is refused.

### E. google_fonts (rejected)

festenao_theme already dropped it (see its pubspec comment: runtime fetch,
and the "not found in assets" failure when offline). Also:

- by default it fetches from fonts.gstatic.com, which raises privacy
  questions for a festival site's visitors and breaks offline use;
- its styles name one family per variant (`'${family}_$variant'` in
  `google_fonts_family_with_variant.dart`), so the bare constant cannot
  be used;
- 9.0 returns `material_ui` types.

### F. Build hook data assets (later)

Dart build hooks can declare data assets, and flutter_tools already bundles
them as `packages/<pkg>/<name>` (`flutterHookResult.dataAssets` in
`asset.dart`). They are still experimental, and they are assets, not
fonts, so the loader of C would still be needed. Revisit once stable.

| | A. app declares | B. `package:` | C. runtime, bare | D. A + generator |
|---|---|---|---|---|
| App pubspec | ~20 lines | dependency only | dependency only | ~20 generated lines |
| App code | none | none | one awaited call | none |
| Bare family names | yes | no (leak, §2.5) | yes | yes |
| Web startup download | every declared family | every declared family | only what is loaded | every declared family |
| Silent Roboto when forgotten | yes | no | yes (mitigated) | caught by CI |

## 4. One package per font? Dart or Flutter?

**One package per family: yes.** A dependency's assets are always bundled
(there is no tree shaking of assets), so a package holding several families
makes every app carry all of them. Today, festenao_theme makes every
festenao app carry JetBrains Mono. With one package per family:

- an app pays only for the fonts it adds;
- the OFL as the package `LICENSE` appears on the license page under the
  package name, with no code (§2.8);
- a font can be updated or re-subset on its own;
- apps outside festenao can reuse it (RobotoMono users, a mono font for
  code screens);
- more fonts are coming: the design spec proposes Inter for body text
  ([design_spec.md](design_spec.md) §0).

**Pure Dart: yes.** Flutter bundles the assets of a pure Dart dependency
(§2.2). Staying pure Dart also keeps the font files usable by Dart programs
(PDF generation, PNG/SVG rendering in a CLI or a Cloud Function). Those read
the files through the package config (`Isolate.resolvePackageUri`, which
works in `dart run` and tests but not in an AOT executable, since that has
no package config). And there is no Flutter SDK constraint to bump.

The loader needs `FontLoader` and `rootBundle`, so it lives once, in a
Flutter package. The font packages only describe their files, using a
record shape so they depend on nothing (records are structural, so no
shared type package is needed):

```dart
/// A font family shipped as assets of a package.
typedef TkFontFamily = ({String family, String package, List<String> files});
```

Where: next to `app_roboto` in `tekartik/app_flutter_utils.dart`. That repo
is public and already a git dependency of festenao_theme (through
`app_common`). Proposed packages:

- `font_poppins/` (`tekartik_font_poppins`);
- `font_jetbrains_mono/` (`tekartik_font_jetbrains_mono`);
- the loader in `app_common` (`tekartik_app_flutter_common_utils`,
  `font.dart`).

`tekartik_app_roboto` can get the same descriptors later and keep its
name.

## 5. Proposed API

The font package (pure Dart):

```yaml
# font_poppins/pubspec.yaml
name: tekartik_font_poppins
description: Poppins font (OFL), Latin subset, for Flutter apps and Dart tools.
environment:
  sdk: ^3.12.0
# Flutter reads this section in any dependency, even a pure Dart one. Plain
# assets, not fonts: the family is registered at runtime under its bare name
# (loadTkFonts). The self-prefixed form gives the same keys an app uses.
flutter:
  assets:
    - packages/tekartik_font_poppins/fonts/Poppins-Regular.ttf
    - packages/tekartik_font_poppins/fonts/Poppins-Italic.ttf
    - packages/tekartik_font_poppins/fonts/Poppins-Medium.ttf
    - packages/tekartik_font_poppins/fonts/Poppins-SemiBold.ttf
    - packages/tekartik_font_poppins/fonts/Poppins-Bold.ttf
```

```dart
// font_poppins/lib/poppins.dart

/// The Poppins family, registered under this bare name by `loadTkFonts`.
const poppinsFontFamily = 'Poppins';

/// The Poppins files: regular, italic, medium, semi bold and bold.
const poppinsFont = (
  family: poppinsFontFamily,
  package: 'tekartik_font_poppins',
  files: [
    'fonts/Poppins-Regular.ttf',
    'fonts/Poppins-Italic.ttf',
    'fonts/Poppins-Medium.ttf',
    'fonts/Poppins-SemiBold.ttf',
    'fonts/Poppins-Bold.ttf',
  ],
);
```

The package also has `LICENSE` (the OFL text), `lib/fonts/*.ttf` and
`tool/subset.sh` (§6).

The loader (Flutter, app_common):

```dart
// tekartik_app_flutter_common_utils/lib/font.dart
typedef TkFontFamily = ({String family, String package, List<String> files});

final _loads = <String, Future<void>>{};

/// Registers each font under its bare family name (or [family] when given,
/// e.g. `'monospace'`), once per name. Await it before `runApp`.
Future<void> loadTkFonts(Iterable<TkFontFamily> fonts) =>
    Future.wait([for (var font in fonts) loadTkFont(font)]);

Future<void> loadTkFont(TkFontFamily font, {String? family}) {
  var name = family ?? font.family;
  return _loads[name] ??= () {
    var loader = FontLoader(name);
    for (var file in font.files) {
      loader.addFont(rootBundle.load('packages/${font.package}/$file'));
    }
    return loader.load();
  }();
}
```

festenao_theme:

```dart
/// Registers Poppins and JetBrains Mono under their bare names, the
/// families the festenao themes ask for. Await it before `runApp`.
Future<void> loadFestenaoFonts() =>
    loadTkFonts([poppinsFont, jetBrainsMonoFont]);
```

An app:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var fonts = loadFestenaoFonts(); // started early, awaited later
  await initFirebase();
  await fonts;
  runApp(const MyApp());
}
```

Its pubspec only lists the dependency: festenao_theme, or for an app
outside festenao, a font package plus app_common.

The screenshot harness (`loadScreenshotFonts`) uses the same descriptors
(`rootBundle` works in `flutter test` on the VM, verified), plus its
aliases (`monospace` and `Courier New` for JetBrains Mono).

## 6. Size: weights and subsets

The festenao themes use weights 400, 500, 600 and 700 (plus the 400
italic), and one app adds 800. The package should keep only the files it
ships; the full family stays upstream.

Subsets made with `pyftsubset`, keeping the layout features, over the
Google Fonts `latin` + `latin-ext` ranges. The mono font also keeps arrows
(U+2190–21FF), box drawing and blocks (U+2500–259F) and geometric shapes
(U+25A0–25FF):

| | Full | Full, gzip | Subset | Subset, gzip |
|---|---|---|---|---|
| Poppins ×5 (400, italic, 500, 600, 700) | 806 KB | 366 KB | 130 KB | 77 KB |
| JetBrains Mono NL ×4 (400 to 700) | 838 KB | 407 KB | 294 KB | 140 KB |

- Kept: French and the European Latin scripts (checked: é, œ, ă, ł, ẞ,
  €, ₹).
- Dropped: the Devanagari of Poppins (94 code points) and the Cyrillic and
  Greek of JetBrains Mono.
- A dropped glyph falls back to a system font on native, or to Noto from
  fonts.gstatic.com on the web (§2.7), as any other script does today.
- Neither OFL file declares a Reserved Font Name, so the subsets can keep
  the family names.

## 7. Plan

**Phase 1: festenao_theme only, no new package.**

1. Migrate the two apps that name `package: 'festenao_theme'` back to the
   bare constant first. Step 2 removes their packaged family.
2. In the festenao_theme pubspec, drop the `fonts:` section and declare the
   nine files as `assets:` in the self-prefixed form
   (`packages/festenao_theme/fonts/poppins/Poppins-Regular.ttf`). These are
   the keys the app blocks already use, so an app that is not migrated yet
   still finds its files, bundled once.
3. Add `loadFestenaoFonts()` (inlined `loadTkFonts`), exported by
   `theme.dart` and `design.dart`. Update the README: a "Fonts" section
   replaces "Apps declare...". Update the skill, which still mentions
   google_fonts.
4. Call it in the festenao runners (`festenaoRunApp`,
   `festenaoRunAdminApp`... in festenao_admin_base_app `run.dart`) and in
   each app's `main`, and remove the apps' pubspec blocks in the same
   commit. Otherwise `'Poppins'` is registered twice, which is harmless but
   loads the files twice.
5. festenao_screenshot: make `loadScreenshotFonts` use the loader, and drop
   the `packages/festenao_theme/...` names.
6. Check: a built web app has no Poppins in `FontManifest.json`, and the
   width probe of §9 draws Poppins in headless Chrome.

**Phase 2: font packages.**

1. Create `tekartik_font_poppins` and `tekartik_font_jetbrains_mono` (pure
   Dart), and `loadTkFonts` in app_common.
2. festenao_theme depends on them, re-exports the constants and removes
   `lib/fonts`. Deprecate `addPoppinsLicense()` and
   `addJetBrainsMonoLicense()` as no-ops: the license now comes from the
   package `LICENSE`, and keeping them would list it twice.
3. Apps outside festenao (RobotoMono users) move when touched;
   `tekartik_app_roboto` gets descriptors.

**Phase 3: subsets.** Ship the §6 subsets with their script, in the font
packages, or in festenao_theme if phase 2 waits.

**Later: Inter** (design spec), as `tekartik_font_inter`. Before choosing
the variable font, check whether `FontWeight` drives its `wght` axis on
Flutter 3.47; otherwise ship static files.

## 8. Open questions

1. Package names and home: `tekartik_font_*` in app_flutter_utils.dart, or
   a new `tekartik/fonts.dart` repo?
2. Should `FestenaoThemeController.load()` load the fonts too? Apps using
   the switcher would need no extra line, but tests that call it would
   start drawing real fonts.
3. Should JetBrains Mono also be registered as `monospace`, so every
   `TextStyle(fontFamily: 'monospace')` (log viewer, credentials screen)
   draws the same mono font on every platform?
4. Subset by default, or ship the full files and offer the subsets as
   `*-latin` files?
5. Does the 800 weight (ExtraBold) belong in the shared package or in the
   one app that uses it?

## 9. Verification (2026-10-10, Flutter 3.47.6, Linux)

- Flutter sources read:
  - `flutter_tools/lib/src/asset.dart`: package font prefix, dependency
    manifests read with no Flutter check, hook data assets;
  - `painting/text_style.dart`: `_package` in `copyWith` and `merge`;
  - `painting/binding.dart`: `fontsChange` → `systemFonts`;
  - `flutter_tools/lib/src/license_collector.dart`;
  - web engine `initialization.dart` (`_downloadAssetFonts` before the first
    frame) and `configuration.dart` (`fontFallbackBaseUrl`).
- Experiment (scratch, not kept):
  - two pure Dart packages, `font_poppins` with `flutter: fonts:` and
    `font_mono` with `flutter: assets:` in both key forms, plus a Flutter
    app depending on them;
  - a `flutter test` printing the font manifest, the asset keys, text widths
    and the families of `Text` widgets under a packaged theme;
  - the same width probe in the `main` of a release web build, run in
    headless Chrome and read from the console log.
- Gotchas:
  - `flutter test` kept a stale `build/unit_test_assets` after a
    dependency's pubspec changed (deleting the folder fixes it);
  - under `flutter test --platform chrome`, `rootBundle.load` of a package
    asset never completed (timeout), so the web check used a real build;
  - under `flutter test`, `rootBundle.load` returns a `SynchronousFuture`,
    and `Future.wait` over such futures completes with an **empty list**
    (they complete during its loop): the loader goes through an `async`
    helper, which always returns a real future.
- Sizes: `pyftsubset` (fonttools 4.61.1) with the §6 ranges, `gzip -9`, and
  the buzzerelio web build for §1.1.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../fonts/jetbrains_mono/jetbrains_mono_font.dart';
import '../fonts/poppins/poppins_font.dart';
import 'font_family.dart';

/// The fonts the festenao themes ask for: [poppinsFont] and
/// [jetBrainsMonoFont].
const festenaoFonts = <FestenaoFontFamily>[poppinsFont, jetBrainsMonoFont];

/// The loads started, by font and registered family name.
final _loads = <(FestenaoFontFamily, String), Future<void>>{};

/// Registers the festenao fonts ([festenaoFonts], then [extra]) under their
/// bare family names, `Poppins` and `JetBrains Mono`, the names the festenao
/// themes ask for, and adds their licenses.
///
/// Nothing to declare in the app pubspec: the files are assets of
/// festenao_theme, registered at runtime (a family declared by a package
/// pubspec could only be reached as `packages/festenao_theme/<family>`, see
/// `doc/font_managment.md`).
///
/// Await it before `runApp`, started early so that it overlaps the rest of
/// the init: text drawn before it completes uses the platform font (it is
/// laid out again when the fonts arrive). Each font is loaded once; a
/// failure is reported ([FlutterError.reportError]), never thrown.
Future<void> loadFestenaoFonts({
  Iterable<FestenaoFontFamily> extra = const [],
}) async {
  addPoppinsLicense();
  addJetBrainsMonoLicense();
  await Future.wait([
    for (var font in [...festenaoFonts, ...extra]) loadFestenaoFont(font),
  ]);
}

/// Registers the files of [font] under its family name, or under [family]
/// when given (e.g. `monospace`), once. A second font of the same family
/// adds its files (weights, styles) to it.
Future<void> loadFestenaoFont(FestenaoFontFamily font, {String? family}) {
  var name = family ?? font.family;
  return _loads[(font, name)] ??= _load(font, name);
}

Future<void> _load(FestenaoFontFamily font, String family) async {
  try {
    // All the files first: FontLoader.load awaits them one after the other,
    // a second failing file would be an unhandled error.
    var files = await Future.wait([
      for (var file in font.files) _loadAsset('packages/${font.package}/$file'),
    ]);
    var loader = FontLoader(family);
    for (var data in files) {
      loader.addFont(Future.value(data));
    }
    await loader.load();
  } catch (e, st) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'festenao_theme',
        context: ErrorDescription('while loading the $family font'),
      ),
    );
  }
}

/// [rootBundle] can answer with a `SynchronousFuture` (it does in flutter
/// test), which `Future.wait` does not support: it completes with an empty
/// list. An async function always returns a real future.
Future<ByteData> _loadAsset(String key) async => await rootBundle.load(key);

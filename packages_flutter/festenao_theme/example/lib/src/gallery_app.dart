import 'package:festenao_theme/design.dart';
import 'package:festenao_theme_example/src/gallery_shell.dart';
import 'package:material_ui/material_ui.dart';

/// The page shown by the gallery.
enum GalleryPage {
  /// A festival day.
  overview('Aujourd\'hui', Icons.today_rounded),

  /// The access of a project: members, invites.
  access('Accès', Icons.group_rounded),

  /// The palette and the components.
  kit('Kit', Icons.palette_rounded);

  /// Label.
  final String label;

  /// Icon.
  final IconData icon;

  const GalleryPage(this.label, this.icon);
}

/// The theme, the brightness and the page shown.
class GalleryState {
  /// The preset.
  final FestenaoThemePreset preset;

  /// Light or dark.
  final Brightness brightness;

  /// The page.
  final GalleryPage page;

  /// The gallery state.
  const GalleryState({
    required this.preset,
    required this.brightness,
    required this.page,
  });

  /// Copy.
  GalleryState copyWith({
    FestenaoThemePreset? preset,
    Brightness? brightness,
    GalleryPage? page,
  }) => GalleryState(
    preset: preset ?? this.preset,
    brightness: brightness ?? this.brightness,
    page: page ?? this.page,
  );
}

/// Holds the [GalleryState].
class GalleryController extends ValueNotifier<GalleryState> {
  /// Starts on [preset] in [brightness].
  GalleryController({
    FestenaoThemePreset? preset,
    Brightness brightness = Brightness.light,
    GalleryPage page = GalleryPage.overview,
  }) : super(
         GalleryState(
           preset: preset ?? festenaoThemePresets.first,
           brightness: brightness,
           page: page,
         ),
       );

  /// Select a preset.
  void selectPreset(FestenaoThemePreset preset) =>
      value = value.copyWith(preset: preset);

  /// The next preset.
  void nextPreset() {
    var index = festenaoThemePresets.indexOf(value.preset);
    selectPreset(
      festenaoThemePresets[(index + 1) % festenaoThemePresets.length],
    );
  }

  /// Light or dark.
  void selectBrightness(Brightness brightness) =>
      value = value.copyWith(brightness: brightness);

  /// Switch light and dark.
  void toggleBrightness() => selectBrightness(
    value.brightness == Brightness.light ? Brightness.dark : Brightness.light,
  );

  /// Select a page.
  void selectPage(GalleryPage page) => value = value.copyWith(page: page);
}

/// Makes the [GalleryController] available.
class GalleryScope extends InheritedNotifier<GalleryController> {
  /// The scope.
  const GalleryScope({
    super.key,
    required GalleryController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller.
  static GalleryController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GalleryScope>()!.notifier!;
}

/// The gallery app.
class GalleryApp extends StatefulWidget {
  /// The controller, created when null.
  final GalleryController? controller;

  /// The gallery app.
  const GalleryApp({super.key, this.controller});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  late final GalleryController _controller =
      widget.controller ??
      GalleryController(
        brightness:
            WidgetsBinding.instance.platformDispatcher.platformBrightness,
      );

  @override
  Widget build(BuildContext context) {
    return GalleryScope(
      controller: _controller,
      child: ValueListenableBuilder<GalleryState>(
        valueListenable: _controller,
        builder: (context, state, _) => MaterialApp(
          title: 'Festenao themes',
          debugShowCheckedModeBanner: false,
          theme: state.preset.themeData(state.brightness),
          home: const GalleryShell(),
        ),
      ),
    );
  }
}

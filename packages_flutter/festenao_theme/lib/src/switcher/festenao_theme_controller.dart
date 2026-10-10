import 'dart:async';

import 'package:festenao_theme/src/design/festenao_theme_presets.dart';
import 'package:material_ui/material_ui.dart';

/// What the user chose: a preset (its id) and light, dark or the system one.
@immutable
class FestenaoThemeChoice {
  /// The id of the preset.
  final String presetId;

  /// Light, dark or the system one.
  final ThemeMode mode;

  /// A choice.
  const FestenaoThemeChoice({
    required this.presetId,
    this.mode = ThemeMode.system,
  });

  /// A copy.
  FestenaoThemeChoice copyWith({String? presetId, ThemeMode? mode}) =>
      FestenaoThemeChoice(
        presetId: presetId ?? this.presetId,
        mode: mode ?? this.mode,
      );

  /// One short string to store (`festenao|dark`).
  String encode() => '$presetId|${mode.name}';

  /// The choice of an [encode]d string, null when it is not one.
  static FestenaoThemeChoice? decode(String? value) {
    if (value == null) {
      return null;
    }
    var parts = value.split('|');
    if (parts.length != 2 || parts.first.isEmpty) {
      return null;
    }
    var mode = ThemeMode.values
        .where((mode) => mode.name == parts.last)
        .firstOrNull;
    if (mode == null) {
      return null;
    }
    return FestenaoThemeChoice(presetId: parts.first, mode: mode);
  }

  @override
  bool operator ==(Object other) =>
      other is FestenaoThemeChoice &&
      other.presetId == presetId &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(presetId, mode);

  @override
  String toString() => 'FestenaoThemeChoice(${encode()})';
}

/// Where a [FestenaoThemeController] keeps the choice: the app plugs its
/// preferences (one string, [FestenaoThemeChoice.encode]).
abstract class FestenaoThemeStore {
  /// The stored choice, null when none.
  FutureOr<String?> read();

  /// Stores [value].
  FutureOr<void> write(String value);

  /// A store on two functions, e.g. on tekartik prefs:
  /// `FestenaoThemeStore.from(read: () => prefs.getString('theme'), write:
  /// (value) => prefs.setString('theme', value))`.
  factory FestenaoThemeStore.from({
    required FutureOr<String?> Function() read,
    required FutureOr<void> Function(String value) write,
  }) = _FestenaoThemeStoreFunctions;

  /// A store in memory (tests, demos).
  factory FestenaoThemeStore.memory([String? value]) =>
      _FestenaoThemeStoreMemory(value);
}

class _FestenaoThemeStoreFunctions implements FestenaoThemeStore {
  final FutureOr<String?> Function() _read;
  final FutureOr<void> Function(String value) _write;

  _FestenaoThemeStoreFunctions({required this._read, required this._write});

  @override
  FutureOr<String?> read() => _read();

  @override
  FutureOr<void> write(String value) => _write(value);
}

class _FestenaoThemeStoreMemory implements FestenaoThemeStore {
  String? _value;

  _FestenaoThemeStoreMemory(this._value);

  @override
  String? read() => _value;

  @override
  void write(String value) => _value = value;
}

/// The theme of an app: the [presets] it offers, the one chosen, light, dark
/// or the system one; written to its [store] on each change.
///
/// ```dart
/// var controller = FestenaoThemeController(
///   presets: festenaoThemePresetsByIds(['festenao', 'obsidian', 'contrast']),
///   store: FestenaoThemeStore.from(read: ..., write: ...),
/// );
/// await controller.load();
/// runApp(FestenaoThemeBuilder(
///   controller: controller,
///   builder: (context, controller) => MaterialApp(
///     theme: controller.theme,
///     darkTheme: controller.darkTheme,
///     themeMode: controller.mode,
///   ),
/// ));
/// ```
class FestenaoThemeController extends ValueNotifier<FestenaoThemeChoice> {
  /// The presets offered, in the order shown, never empty.
  final List<FestenaoThemePreset> presets;

  /// Where the choice is kept, none by default.
  final FestenaoThemeStore? store;

  final _themes = <(String, Brightness), ThemeData>{};

  /// The [presets] the app offers (every festenao preset by default), the
  /// [initial] one (the first of [presets] by default) in [mode].
  FestenaoThemeController({
    List<FestenaoThemePreset>? presets,
    FestenaoThemePreset? initial,
    ThemeMode mode = ThemeMode.system,
    this.store,
  }) : presets = _checkPresets(presets ?? festenaoThemePresets),
       super(
         FestenaoThemeChoice(
           presetId: (initial ?? _checkPresets(presets).first).id,
           mode: mode,
         ),
       );

  static List<FestenaoThemePreset> _checkPresets(
    List<FestenaoThemePreset>? presets,
  ) {
    presets ??= festenaoThemePresets;
    if (presets.isEmpty) {
      throw ArgumentError.value(presets, 'presets', 'no preset');
    }
    return List.unmodifiable(presets);
  }

  /// The chosen preset, the first offered when the choice is not offered.
  FestenaoThemePreset get preset =>
      presets.where((preset) => preset.id == value.presetId).firstOrNull ??
      presets.first;

  /// Light, dark or the system one.
  ThemeMode get mode => value.mode;

  /// The light theme of the chosen preset.
  ThemeData get theme => themeOf(preset, Brightness.light);

  /// The dark theme of the chosen preset.
  ThemeData get darkTheme => themeOf(preset, Brightness.dark);

  /// The theme of [preset] in [brightness], built once.
  ThemeData themeOf(FestenaoThemePreset preset, Brightness brightness) =>
      _themes[(preset.id, brightness)] ??= preset.themeData(brightness);

  /// Reads the [store]: a stored preset that is not offered (any more) is
  /// replaced by the first offered.
  Future<void> load() async {
    var choice = FestenaoThemeChoice.decode(await store?.read());
    if (choice == null) {
      return;
    }
    _set(
      choice.copyWith(
        presetId: presets.any((preset) => preset.id == choice.presetId)
            ? choice.presetId
            : presets.first.id,
      ),
      save: false,
    );
  }

  /// Chooses [preset] (one of [presets]).
  void selectPreset(FestenaoThemePreset preset) =>
      _set(value.copyWith(presetId: preset.id));

  /// The next preset offered, the first after the last.
  void nextPreset() {
    var index = presets.indexOf(preset);
    selectPreset(presets[(index + 1) % presets.length]);
  }

  /// Chooses light, dark or the system one.
  void selectMode(ThemeMode mode) => _set(value.copyWith(mode: mode));

  /// System, then light, then dark.
  void nextMode() => selectMode(switch (mode) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  });

  void _set(FestenaoThemeChoice choice, {bool save = true}) {
    if (choice == value) {
      return;
    }
    value = choice;
    if (save) {
      unawaited(Future.sync(() => store?.write(choice.encode())));
    }
  }

  /// The controller of the closest [FestenaoThemeScope].
  static FestenaoThemeController of(BuildContext context) {
    var controller = maybeOf(context);
    assert(controller != null, 'No FestenaoThemeScope above');
    return controller!;
  }

  /// The controller of the closest [FestenaoThemeScope], if any.
  static FestenaoThemeController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<FestenaoThemeScope>()
      ?.notifier;
}

/// Makes a [FestenaoThemeController] available to the switcher widgets.
class FestenaoThemeScope extends InheritedNotifier<FestenaoThemeController> {
  /// The scope.
  const FestenaoThemeScope({
    super.key,
    required FestenaoThemeController controller,
    required super.child,
  }) : super(notifier: controller);
}

/// The [FestenaoThemeScope] of [controller] around what [builder] builds
/// (the `MaterialApp`), rebuilt on each change of the theme.
class FestenaoThemeBuilder extends StatelessWidget {
  /// The controller.
  final FestenaoThemeController controller;

  /// Builds the app with `controller.theme`, `controller.darkTheme` and
  /// `controller.mode`.
  final Widget Function(
    BuildContext context,
    FestenaoThemeController controller,
  )
  builder;

  /// The builder.
  const FestenaoThemeBuilder({
    super.key,
    required this.controller,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => FestenaoThemeScope(
    controller: controller,
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => builder(context, controller),
    ),
  );
}

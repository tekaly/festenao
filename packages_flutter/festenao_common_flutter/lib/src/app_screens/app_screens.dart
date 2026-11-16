import 'package:material_ui/material_ui.dart';

/// The splash while an app starts, or why it could not start: its [logo],
/// its [title], then a spinner, or [errorTitle] (when given) and the
/// [error] (technical, selectable).
class FestenaoSplashScreen extends StatelessWidget {
  /// The logo of the app, at its splash size.
  final Widget logo;

  /// The name of the app.
  final String title;

  /// The color of [title], the theme's by default.
  final Color? titleColor;

  /// Why the app could not start, null while starting.
  final String? error;

  /// The line above [error] ("could not start"), none when null.
  final String? errorTitle;

  /// The splash of the app [title] with its [logo], [error] when it could
  /// not start.
  const FestenaoSplashScreen({
    super.key,
    required this.logo,
    required this.title,
    this.titleColor,
    this.error,
    this.errorTitle,
  });

  @override
  Widget build(BuildContext context) {
    var error = this.error;
    var errorTitle = this.errorTitle;
    var textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              logo,
              const SizedBox(height: 16),
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 24),
              if (error == null)
                const CircularProgressIndicator()
              else ...[
                if (errorTitle != null) ...[
                  Text(errorTitle, style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                ],
                SelectableText(error, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The about screen of an app: [header] (its title block), [text] (what
/// it is), an optional [setting] (the language), [versionText] and the
/// [actions] (a [FestenaoLicensesButton] in the layout of the app).
class FestenaoAboutScreen extends StatelessWidget {
  /// The title of the app bar.
  final String title;

  /// The title block of the app (logo, name, tagline).
  final Widget header;

  /// What the app is.
  final String text;

  /// A setting shown on the screen (the language), none when null.
  final Widget? setting;

  /// The version line (version, app id, how firebase is reached).
  final String versionText;

  /// The buttons at the bottom (the licences).
  final Widget actions;

  /// The about screen [title] of an app, see the fields.
  const FestenaoAboutScreen({
    super.key,
    required this.title,
    required this.header,
    required this.text,
    this.setting,
    required this.versionText,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    var setting = this.setting;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          header,
          const SizedBox(height: 24),
          Text(text),
          const SizedBox(height: 16),
          if (setting != null) ...[setting, const SizedBox(height: 16)],
          Text(versionText, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          actions,
        ],
      ),
    );
  }
}

/// The button showing the licences of the packages of
/// [applicationName] ([applicationVersion]).
class FestenaoLicensesButton extends StatelessWidget {
  /// The label of the button ("Licences").
  final String label;

  /// The name of the app on the licences page.
  final String applicationName;

  /// Its version, none when null.
  final String? applicationVersion;

  /// An outlined [label] button opening the licences page.
  const FestenaoLicensesButton({
    super.key,
    required this.label,
    required this.applicationName,
    this.applicationVersion,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () => showLicensePage(
      context: context,
      applicationName: applicationName,
      applicationVersion: applicationVersion,
    ),
    child: Text(label),
  );
}

/// The language setting of an app, among its languages [values] (each
/// named in itself by [name], so that anyone finds theirs) or the device
/// one ([automaticLabel], null).
class FestenaoLanguageSetting<L> extends StatelessWidget {
  /// The title of the setting ("Language").
  final String title;

  /// The choice following the device language (null).
  final String automaticLabel;

  /// The language chosen, null to follow the device.
  final L? value;

  /// The languages of the app.
  final List<L> values;

  /// The name of a language in itself (`Français`).
  final String Function(L language) name;

  /// Called with the language chosen (null: the device one).
  final ValueChanged<L?> onChanged;

  /// The language setting [title], see the fields.
  const FestenaoLanguageSetting({
    super.key,
    required this.title,
    required this.automaticLabel,
    required this.value,
    required this.values,
    required this.name,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.translate, size: 20),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
      const SizedBox(height: 8),
      DropdownButton<L?>(
        value: value,
        onChanged: onChanged,
        items: [
          DropdownMenuItem(child: Text(automaticLabel)),
          for (var language in values)
            DropdownMenuItem(value: language, child: Text(name(language))),
        ],
      ),
    ],
  );
}

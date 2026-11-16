import 'package:festenao_common_flutter/app_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

enum _Lang { en, fr }

void main() {
  group('FestenaoSplashScreen', () {
    testWidgets('starting', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FestenaoSplashScreen(logo: Icon(Icons.edit), title: 'My app'),
        ),
      );
      expect(find.text('My app'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('could not start', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FestenaoSplashScreen(
            logo: Icon(Icons.edit),
            title: 'My app',
            error: 'no firebase',
            errorTitle: 'Could not start',
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Could not start'), findsOneWidget);
      expect(find.text('no firebase'), findsOneWidget);
    });
  });

  testWidgets('FestenaoAboutScreen', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FestenaoAboutScreen(
          title: 'About',
          header: Text('My app'),
          text: 'What it is',
          setting: Text('A setting'),
          versionText: 'Version 1.0.0',
          actions: FestenaoLicensesButton(
            label: 'Licences',
            applicationName: 'My app',
          ),
        ),
      ),
    );
    for (var text in [
      'About',
      'My app',
      'What it is',
      'A setting',
      'Version 1.0.0',
      'Licences',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    await tester.tap(find.text('Licences'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('FestenaoLanguageSetting', (tester) async {
    _Lang? chosen = _Lang.en;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FestenaoLanguageSetting<_Lang>(
              title: 'Language',
              automaticLabel: 'Automatic',
              value: chosen,
              values: _Lang.values,
              name: (lang) => switch (lang) {
                _Lang.en => 'English',
                _Lang.fr => 'Français',
              },
              onChanged: (lang) => setState(() => chosen = lang),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français').last);
    await tester.pumpAndSettle();
    expect(chosen, _Lang.fr);
  });
}

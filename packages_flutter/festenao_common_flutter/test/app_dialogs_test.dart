import 'package:festenao_common_flutter/app_dialogs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// A scaffold, its context once built.
Future<BuildContext> _pumpApp(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (scaffoldContext) {
            context = scaffoldContext;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return context;
}

void main() {
  testWidgets('FestenaoMessageView', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FestenaoMessageView(
            icon: Icons.inbox,
            message: 'Nothing yet',
            action: TextButton(onPressed: () {}, child: const Text('Add')),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.inbox), findsOneWidget);
    expect(find.text('Nothing yet'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });

  group('festenaoConfirmDialog', () {
    testWidgets('material labels, confirmed', (tester) async {
      var context = await _pumpApp(tester);
      var result = festenaoConfirmDialog(
        context,
        title: 'Delete?',
        message: 'For good',
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete?'), findsOneWidget);
      expect(find.text('For good'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });

    testWidgets('own labels, cancelled', (tester) async {
      var context = await _pumpApp(tester);
      var result = festenaoConfirmDialog(
        context,
        title: 'Supprimer ?',
        confirm: 'Supprimer',
        cancel: 'Annuler',
        destructive: true,
      );
      await tester.pumpAndSettle();
      expect(find.text('Supprimer'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });
  });

  group('festenaoTextDialog', () {
    testWidgets('the text entered', (tester) async {
      var context = await _pumpApp(tester);
      var result = festenaoTextDialog(
        context,
        title: 'Name',
        initial: 'old',
        confirm: 'Rename',
      );
      await tester.pumpAndSettle();
      expect(find.text('old'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'new');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(await result, 'new');
    });

    testWidgets('null when cancelled', (tester) async {
      var context = await _pumpApp(tester);
      var result = festenaoTextDialog(context, title: 'Name');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });
  });

  group('festenaoRunWithSnack', () {
    testWidgets('success', (tester) async {
      var context = await _pumpApp(tester);
      var done = await festenaoRunWithSnack(
        context,
        () async {},
        success: 'Saved',
      );
      await tester.pump();
      expect(done, isTrue);
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('the error, as is or worded', (tester) async {
      var context = await _pumpApp(tester);
      var done = await festenaoRunWithSnack(
        context,
        () async => throw StateError('offline'),
      );
      await tester.pump();
      expect(done, isFalse);
      expect(find.text('Bad state: offline'), findsOneWidget);

      done = await festenaoRunWithSnack(
        context,
        () async => throw StateError('offline'),
        errorText: (error) => 'No network',
      );
      await tester.pump();
      expect(done, isFalse);
      expect(find.text('No network'), findsOneWidget);
    });
  });
}

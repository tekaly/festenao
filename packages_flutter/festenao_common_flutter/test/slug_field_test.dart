import 'package:festenao_common_flutter/festenao_slug_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('FestenaoSlugInputFormatter', () {
    const formatter = FestenaoSlugInputFormatter();
    expect(formatter.format('Solaris'), 'solaris');
    expect(formatter.format('Solaris '), 'solaris-');
    expect(formatter.format('Solaris 2025'), 'solaris-2025');
    expect(formatter.format('Café & co'), 'cafe-co');
    expect(formatter.format('--'), '');
    expect(formatter.format('a' * 50), 'a' * festenaoSlugMaxLength);
  });

  test('FestenaoSlugInputFormatter typed key by key', () {
    const formatter = FestenaoSlugInputFormatter();
    String type(String text) {
      var value = TextEditingValue.empty;
      for (var char in text.split('')) {
        var typed = value.text + char;
        value = formatter.formatEditUpdate(
          value,
          TextEditingValue(
            text: typed,
            selection: TextSelection.collapsed(offset: typed.length),
          ),
        );
      }
      return value.text;
    }

    expect(type('Été 2025'), 'ete-2025');
    // Letters mapped outside Latin-1 are no separator.
    expect(type('Cœur'), 'coeur');
    expect(type('SŒUR'), 'soeur');
    expect(type('Ÿes'), 'yes');
    expect(type('a b'), 'a-b');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('FestenaoSlugField', (tester) async {
    var controller = TextEditingController();
    var statuses = <FestenaoSlugStatus>[];
    var taken = {'taken-slug'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FestenaoSlugField(
            controller: controller,
            currentSlug: 'mine',
            isAvailable: (slug) async => !taken.contains(slug),
            prefixText: 'app.web.app/e/',
            onStatusChanged: statuses.add,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(statuses, [FestenaoSlugStatus.empty]);

    await tester.enterText(find.byType(TextField), 'Ab');
    await tester.pump();
    expect(controller.text, 'ab');
    expect(statuses.last, FestenaoSlugStatus.invalid);
    expect(find.text('At least 3 characters'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Taken slug');
    await tester.pump();
    expect(controller.text, 'taken-slug');
    expect(statuses.last, FestenaoSlugStatus.checking);
    await tester.pump(const Duration(milliseconds: 500));
    expect(statuses.last, FestenaoSlugStatus.taken);
    expect(find.text('Already taken'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'free-slug');
    await tester.pump(const Duration(milliseconds: 500));
    expect(statuses.last, FestenaoSlugStatus.available);
    expect(statuses.last.isAcceptable, isTrue);

    await tester.enterText(find.byType(TextField), 'mine');
    await tester.pump();
    expect(statuses.last, FestenaoSlugStatus.current);

    await tester.enterText(find.byType(TextField), 'admin');
    await tester.pump();
    expect(find.text('This word is reserved'), findsOneWidget);
  });
}

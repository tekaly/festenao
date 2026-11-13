import 'package:festenao_admin_base_app/view/calendar_edit_tile.dart';
import 'package:festenao_common/data/calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pumpTile(
  WidgetTester tester,
  ValueNotifier<CalendarDay?> day,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Form(
            child: CalendarFormFieldTile(
              context: context,
              valueNotifier: day,
              labelText: 'Jour',
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const timeout = Timeout(Duration(minutes: 2));
  testWidgets('the tile shows the day as yyyy-MM-dd', (tester) async {
    var day = ValueNotifier<CalendarDay?>(CalendarDay(text: '2026-07-14'));
    addTearDown(day.dispose);
    await _pumpTile(tester, day);
    expect(find.text('2026-07-14'), findsOneWidget);
  }, timeout: timeout);

  testWidgets('the day of an event of two years ago can be changed', (
    tester,
  ) async {
    var year = DateTime.now().year - 2;
    var day = ValueNotifier<CalendarDay?>(CalendarDay(text: '$year-07-14'));
    addTearDown(day.dispose);
    await _pumpTile(tester, day);
    await tester.tap(find.byType(CalendarEditTile));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
    // Pick the 15th of the same month.
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(day.value!.text, '$year-07-15');
  }, timeout: timeout);
}

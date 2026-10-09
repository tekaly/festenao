import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, Widget child, {double width = 800}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: festenaoThemeFestenao.themeData(Brightness.light),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

void main() {
  test('initials', () {
    expect(fkInitials('Camille Martin'), 'CM');
    expect(fkInitials('camille.martin@test.local'), 'CM');
    expect(fkInitials('ines'), 'I');
    expect(fkInitials('-P3R0_OkzQ3rNhDvd454'), 'PO');
    expect(fkInitials('  '), '?');
    expect(fkInitials('Élise'), 'É');
  });

  testWidgets('a row puts its badges under the subtitle when narrow', (
    tester,
  ) async {
    var row = FkRow(
      leading: const FkAvatar('Camille Martin'),
      title: 'Camille Martin',
      subtitle: 'camille@test.local',
      badges: const [FkStatusPill('Admin', status: FkStatus.accent)],
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
    Offset pillOf() => tester.getTopLeft(find.text('Admin'));
    Offset subtitleOf() => tester.getTopLeft(find.text('camille@test.local'));

    await _pump(tester, row);
    expect(pillOf().dy, lessThan(subtitleOf().dy + 4));
    expect(pillOf().dx, greaterThan(subtitleOf().dx));

    await _pump(tester, row, width: 320);
    expect(pillOf().dy, greaterThan(subtitleOf().dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long status pill does not overflow', (tester) async {
    await _pump(
      tester,
      const Row(
        children: [
          Expanded(child: Text('A long title')),
          Flexible(
            child: FkStatusPill(
              'A very long status that does not fit in the row at all',
              status: FkStatus.warn,
              dot: true,
            ),
          ),
        ],
      ),
      width: 200,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('list card and empty state', (tester) async {
    await _pump(
      tester,
      Column(
        children: [
          const FkListCard(
            children: [
              FkRow(title: 'One'),
              FkRow(title: 'Two'),
            ],
          ),
          FkEmpty(
            icon: Icons.group_outlined,
            message: 'Nobody yet',
            action: FilledButton(onPressed: () {}, child: const Text('Add')),
          ),
        ],
      ),
    );
    expect(find.byType(Divider), findsOneWidget);
    expect(find.text('Nobody yet'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });
}

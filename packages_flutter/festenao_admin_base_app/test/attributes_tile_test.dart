import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/view/attributes_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _Ctx implements FestenaoAdminAppProjectContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumps(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<ValueNotifier<List<CvAttribute>?>> _pumpTile(WidgetTester tester) async {
  festenaoAdminAppShowPathBar = false;
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  var attributes = ValueNotifier<List<CvAttribute>?>([
    CvAttribute()
      ..name.v = 'site'
      ..value.v = 'https://example.com',
    CvAttribute()..name.v = 'other',
  ]);
  addTearDown(attributes.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AttributesTile(
          options: AttributesTileOptions(attributes: attributes),
          projectContext: _Ctx(),
        ),
      ),
    ),
  );
  return attributes;
}

void main() {
  const timeout = Timeout(Duration(minutes: 2));
  testWidgets('"Supprimer" in the attribute edit screen removes it', (
    tester,
  ) async {
    var attributes = await _pumpTile(tester);
    // Open the first attribute, delete it from its screen.
    await tester.tap(find.text('site'));
    await _pumps(tester);
    await tester.tap(find.byTooltip('Supprimer'));
    await _pumps(tester);
    expect(find.byTooltip('Supprimer'), findsNothing, reason: 'screen popped');
    expect(attributes.value!.map((e) => e.name.v), ['other']);
  }, timeout: timeout);

  testWidgets('a new attribute has no delete action', (tester) async {
    await _pumpTile(tester);
    await tester.tap(find.text('Add attribute'));
    await _pumps(tester);
    expect(find.text('Attribute'), findsOneWidget);
    expect(find.byTooltip('Supprimer'), findsNothing);
  }, timeout: timeout);
}

import 'package:festenao_theme/design.dart';
import 'package:festenao_theme_example/src/gallery_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (var (name, size) in [
    ('phone', const Size(400, 860)),
    ('tablet', const Size(800, 1000)),
    ('desk', const Size(1440, 900)),
  ]) {
    testWidgets('every page on a $name, light and dark', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var controller = GalleryController(preset: festenaoThemeArcade);
      await tester.pumpWidget(GalleryApp(controller: controller));
      for (var brightness in Brightness.values) {
        controller.selectBrightness(brightness);
        for (var page in GalleryPage.values) {
          controller.selectPage(page);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: page.name);
        }
      }
      // The navigation of the size class is there.
      if (size.width < FestenaoSpace.medium) {
        expect(find.byType(NavigationBar), findsOneWidget);
      } else if (size.width < FestenaoSpace.expanded) {
        expect(find.byType(NavigationRail), findsOneWidget);
      } else {
        expect(find.text('Festen Orga'), findsOneWidget);
      }
    });
  }

  testWidgets('the picker switches the preset', (tester) async {
    var controller = GalleryController();
    await tester.pumpWidget(GalleryApp(controller: controller));
    await tester.tap(find.byTooltip('Thème suivant'));
    await tester.pumpAndSettle();
    expect(controller.value.preset, festenaoThemePresets[1]);
    var theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(
      theme.colorScheme.primary,
      festenaoThemePresets[1].palette(theme.brightness).accent,
    );
  });
}

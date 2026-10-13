import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_blog_demo_providers.dart';
import 'package:festenao_dashboard_base_app/src/provider/sdb_db_providers.dart';
import 'package:festenao_dashboard_base_app/src/screen/content_image_edit_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Like the image view screen: keeps the image entry loaded, then opens the
/// edit screen.
class _ViewScreen extends ConsumerWidget {
  const _ViewScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var image = ref.watch(imageEntryProvider('p', 'd', 'i1')).value;
    return Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => const ContentImageEditScreen(
              projectId: 'p',
              dataId: 'd',
              imageId: 'i1',
            ),
          ),
        ),
        child: Text('view ${image?.name.v}'),
      ),
    );
  }
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  initSdfConstructors();
  testWidgets('edit opened from the view screen shows the image', (
    tester,
  ) async {
    late SdfContentSdb sdb;
    await tester.runAsync(() async {
      var db = await sdbFactoryMemory.openDatabase(
        'content_image_edit.db',
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: SdbDatabaseSchema(stores: [sdfImageStore.schema()]),
        ),
      );
      sdb = SdfContentSdb(fs: newFileSystemMemory(), db: db);
      await sdb.putImage(
        'i1',
        SdfImage()
          ..name.v = 'name'
          ..copyright.v = 'copyright'
          ..mediaId.v = 'm1',
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentSdbProvider('p', 'd').overrideWith((ref) => Stream.value(sdb)),
        ],
        child: const MaterialApp(home: _ViewScreen()),
      ),
    );
    await _pumpUntil(tester, find.text('view name'));
    expect(find.text('view name'), findsOneWidget);

    await tester.tap(find.text('view name'));
    await _pumpUntil(tester, find.text('copyright'));
    // The form shows the loaded image (it stayed empty, then saved nulls).
    expect(find.text('name'), findsOneWidget);
    expect(find.text('copyright'), findsOneWidget);
    await tester.runAsync(() => sdb.db.close());
  });
}

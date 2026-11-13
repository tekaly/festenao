import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_admin_base_app/screen/admin_meta_general_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/sembast/projects_db_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// A single project context on a memory synced db.
class _Ctx implements SingleFestenaoAdminAppProjectContext {
  _Ctx(this.syncedDb);
  @override
  final SyncedDb syncedDb;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Bounded: lets the memory database and the screen settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('meta general edit screen keeps the typed text on a rebuild', (
    tester,
  ) async {
    festenaoAdminAppShowPathBar = false;
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Read by the db bloc dispose (none to release for a single project).
    globalProjectsDbBloc = ProjectsDbBloc();
    var syncedDb = SyncedDb.newInMemory(syncedStoreNames: ['meta']);
    var bloc = AdminMetaGeneralEditScreenBloc(projectContext: _Ctx(syncedDb));
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AdminMetaGeneralEditScreenBloc>(
          blocBuilder: () => bloc,
          child: const AdminMetaGeneralEditScreen(),
        ),
      ),
    );
    await _settle(tester);
    var nameField = find.byType(TextField).first;
    await tester.enterText(nameField, 'My festival');
    // The state emitted again (the screen rebuilt).
    bloc.add(AdminMetaGeneralEditScreenBlocState(DbMetaGeneral()));
    await _settle(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'My festival',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => syncedDb.close());
  }, timeout: const Timeout(Duration(minutes: 2)));
}

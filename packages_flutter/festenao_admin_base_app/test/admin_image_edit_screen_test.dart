import 'package:festenao_admin_base_app/admin_app/festenao_admin_app.dart';
import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_admin_base_app/screen/admin_image_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_image_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_common/text/text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart' as sembast;
import 'package:tekartik_app_prefs/app_prefs.dart';

class _Ctx implements FestenaoAdminAppProjectContext {
  @override
  String get storageBucket => 'bucket';
  @override
  String get projectId => 'p1';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DbBloc implements AdminAppProjectContextDbBloc {
  _DbBloc(this.db);
  final sembast.Database db;
  @override
  FestenaoAdminAppProjectContext get projectContext => _Ctx();
  @override
  Future<sembast.Database> grabDatabase() async => db;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Bloc extends AdminImageEditScreenBloc {
  _Bloc(this._dbBloc, {required super.imageId})
    : super(param: null, projectContext: _Ctx());
  final _DbBloc _dbBloc;
  @override
  AdminAppProjectContextDbBloc get dbBloc => _dbBloc;
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

Future<sembast.Database> _pumpScreen(WidgetTester tester) async {
  festenaoAdminAppShowPathBar = false;
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  globalFestenaoAdminApp.prefs = (await tester.runAsync(
    () => newPrefsFactoryMemory().openPreferences('prefs.db'),
  ))!;
  var db = (await tester.runAsync(
    () => sembast.newDatabaseFactoryMemory().openDatabase('content.db'),
  ))!;
  // An image id without record (nothing to fetch).
  var bloc = _Bloc(_DbBloc(db), imageId: 'i1');
  await tester.pumpWidget(
    MaterialApp(
      home: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => BlocProvider<AdminImageEditScreenBloc>(
            blocBuilder: () => bloc,
            child: const AdminImageEditScreen(),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return db;
}

void main() {
  const timeout = Timeout(Duration(minutes: 2));
  testWidgets('the id of an existing image is read only', (tester) async {
    var db = await _pumpScreen(tester);
    var idField = tester.widget<TextField>(
      find.widgetWithText(TextField, textIdLabel),
    );
    expect(idField.controller!.text, 'i1');
    expect(idField.readOnly, isTrue);
    await tester.runAsync(() => db.close());
  }, timeout: timeout);

  testWidgets('download is disabled until an image is loaded', (tester) async {
    var db = await _pumpScreen(tester);
    // No image loaded: Download is disabled (it threw a null check error).
    var download = find.widgetWithText(ElevatedButton, 'Download image');
    await tester.ensureVisible(download);
    expect(tester.widget<ElevatedButton>(download).onPressed, isNull);
    await tester.tap(download, warnIfMissed: false);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => db.close());
  }, timeout: timeout);
}

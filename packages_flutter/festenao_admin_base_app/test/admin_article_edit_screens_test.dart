import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_admin_base_app/screen/admin_artist_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_artist_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/admin_event_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_event_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/admin_info_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_info_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_common/data/src/model/db_models.dart';
import 'package:festenao_common/text/text.dart';
import 'package:flutter_test/flutter_test.dart' hide Finder;
import 'package:flutter_test/flutter_test.dart' as ft show Finder;
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';

class _Ctx implements FestenaoAdminAppProjectContext {
  @override
  String get storageBucket => 'bucket';
  @override
  String get projectId => 'p1';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A project db bloc on a memory database.
class _DbBloc implements AdminAppProjectContextDbBloc {
  _DbBloc(this.db);
  final Database db;
  @override
  FestenaoAdminAppProjectContext get projectContext => _Ctx();
  @override
  Future<Database> grabDatabase() async => db;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EventBloc extends AdminEventEditScreenBloc {
  _EventBloc(this._dbBloc, {super.eventId, DbEvent? template})
    : super(
        param: AdminEventEditScreenParam(event: template),
        projectContext: _Ctx(),
      );
  final _DbBloc _dbBloc;
  @override
  AdminAppProjectContextDbBloc get dbBloc => _dbBloc;
}

class _ArtistBloc extends AdminArtistEditScreenBloc {
  _ArtistBloc(this._dbBloc, {super.artistId}) : super(projectContext: _Ctx());
  final _DbBloc _dbBloc;
  @override
  AdminAppProjectContextDbBloc get dbBloc => _dbBloc;
}

class _InfoBloc extends AdminInfoEditScreenBloc {
  _InfoBloc(this._dbBloc, {super.infoId, super.info})
    : super(projectContext: _Ctx());
  final _DbBloc _dbBloc;
  @override
  AdminAppProjectContextDbBloc get dbBloc => _dbBloc;
}

Future<Database> _openDb(WidgetTester tester) async => (await tester.runAsync(
  () => newDatabaseFactoryMemory().openDatabase('content.db'),
))!;

/// Bounded: lets the memory database and the screen settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpScreen<T extends BaseBloc>(
  WidgetTester tester, {
  required T bloc,
  required Widget screen,
}) async {
  festenaoAdminAppShowPathBar = false;
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Navigator(
        // A new screen each time (not the route of the previous one).
        key: UniqueKey(),
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) =>
              BlocProvider<T>(blocBuilder: () => bloc, child: screen),
        ),
      ),
    ),
  );
  await _settle(tester);
}

ft.Finder get _idField => find.widgetWithText(TextField, textIdLabel);

String _idText(WidgetTester tester) =>
    tester.widget<TextField>(_idField).controller!.text;

bool _idReadOnly(WidgetTester tester) =>
    tester.widget<TextField>(_idField).readOnly;

Future<void> _put(WidgetTester tester, Database db, DbArticle article) async {
  await tester.runAsync(() => article.put(db));
}

void main() {
  initFestenaoDbBuilders();
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets('the event edit screen saves the day as yyyy-MM-dd', (
    tester,
  ) async {
    var db = await _openDb(tester);
    var template = DbEvent()
      ..day.v = '2026-07-14'
      ..beginTime.v = '20:00'
      ..endTime.v = '21:00';
    await _pumpScreen<AdminEventEditScreenBloc>(
      tester,
      bloc: _EventBloc(_DbBloc(db), template: template),
      screen: const AdminEventEditScreen(),
    );
    // Shown as the day, not Day(...).
    expect(find.text('2026-07-14'), findsOneWidget);
    await tester.enterText(_idField, 'e1');
    await tester.tap(find.byIcon(Icons.save));
    await _settle(tester);
    var event = (await tester.runAsync(
      () => dbEventStoreRef.record('e1').get(db),
    ))!;
    expect(event.day.v, '2026-07-14');
    await tester.runAsync(() => db.close());
  }, timeout: timeout);

  testWidgets('an event created from an artist never takes the id of an '
      'existing event', (tester) async {
    var db = await _openDb(tester);
    // The first concert of the artist a1.
    await _put(
      tester,
      db,
      dbEventStoreRef.record('a1').cv()
        ..name.v = 'Concert 1'
        ..day.v = '2026-07-14'
        ..beginTime.v = '20:00'
        ..endTime.v = '21:00',
    );
    // Artist screen > "Créer event" (the day picked in the calendar, here in
    // the template).
    var template = DbEvent()
      ..day.v = '2026-07-15'
      ..beginTime.v = '20:00'
      ..endTime.v = '21:00'
      ..attributes.v = [CvAttribute()..value.v = attrMakeFromArtistId('a1')];
    await _pumpScreen<AdminEventEditScreenBloc>(
      tester,
      bloc: _EventBloc(_DbBloc(db), template: template),
      screen: const AdminEventEditScreen(),
    );
    // No id prefilled from the artist.
    expect(_idText(tester), isEmpty);
    // The existing id typed: refused.
    await tester.enterText(_idField, 'a1');
    await tester.enterText(
      find.widgetWithText(TextField, textNameLabel),
      'Concert 2',
    );
    await tester.tap(find.byIcon(Icons.save));
    await _settle(tester);
    expect(find.text('event a1 already exists'), findsOneWidget);
    var events = (await tester.runAsync(() => dbEventStoreRef.find(db)))!;
    expect(events.map((e) => e.name.v), ['Concert 1']);
    await tester.runAsync(() => db.close());
  }, timeout: timeout);

  testWidgets('a duplicated event or info has no id prefilled', (tester) async {
    var db = await _openDb(tester);
    var source = dbEventStoreRef.record('e1').cv()
      ..name.v = 'Concert'
      ..day.v = '2026-07-14'
      ..beginTime.v = '20:00'
      ..endTime.v = '21:00';
    await _put(tester, db, source);
    await _pumpScreen<AdminEventEditScreenBloc>(
      tester,
      bloc: _EventBloc(_DbBloc(db), template: source),
      screen: const AdminEventEditScreen(),
    );
    expect(_idText(tester), isEmpty);
    expect(_idReadOnly(tester), isFalse);

    var info = dbInfoStoreRef.record('i1').cv()..name.v = 'Some info';
    await _put(tester, db, info);
    await _pumpScreen<AdminInfoEditScreenBloc>(
      tester,
      bloc: _InfoBloc(_DbBloc(db), info: info),
      screen: const AdminInfoEditScreen(),
    );
    expect(find.text('Info'), findsOneWidget);
    expect(_idText(tester), isEmpty);
    await tester.runAsync(() => db.close());
  }, timeout: timeout);

  testWidgets('the id of an existing artist or event is read only', (
    tester,
  ) async {
    var db = await _openDb(tester);
    await _put(tester, db, dbArtistStoreRef.record('a1').cv()..name.v = 'A');
    await _put(
      tester,
      db,
      dbEventStoreRef.record('e1').cv()
        ..name.v = 'E'
        ..day.v = '2026-07-14'
        ..beginTime.v = '20:00'
        ..endTime.v = '21:00',
    );
    await _pumpScreen<AdminArtistEditScreenBloc>(
      tester,
      bloc: _ArtistBloc(_DbBloc(db), artistId: 'a1'),
      screen: const AdminArtistEditScreen(),
    );
    expect(_idText(tester), 'a1');
    expect(_idReadOnly(tester), isTrue);
    await _pumpScreen<AdminEventEditScreenBloc>(
      tester,
      bloc: _EventBloc(_DbBloc(db), eventId: 'e1'),
      screen: const AdminEventEditScreen(),
    );
    expect(find.text('Event'), findsOneWidget);
    expect(_idText(tester), 'e1');
    expect(_idReadOnly(tester), isTrue);
    await tester.runAsync(() => db.close());
  }, timeout: timeout);

  testWidgets('a missing artist, event or info shows "Non trouvé"', (
    tester,
  ) async {
    var db = await _openDb(tester);
    await _pumpScreen<AdminArtistEditScreenBloc>(
      tester,
      bloc: _ArtistBloc(_DbBloc(db), artistId: 'missing'),
      screen: const AdminArtistEditScreen(),
    );
    expect(find.text('Non trouvé'), findsOneWidget);
    expect(find.byIcon(Icons.save), findsNothing);
    await _pumpScreen<AdminEventEditScreenBloc>(
      tester,
      bloc: _EventBloc(_DbBloc(db), eventId: 'missing'),
      screen: const AdminEventEditScreen(),
    );
    expect(find.text('Event'), findsOneWidget);
    expect(find.text('Non trouvé'), findsOneWidget);
    await _pumpScreen<AdminInfoEditScreenBloc>(
      tester,
      bloc: _InfoBloc(_DbBloc(db), infoId: 'missing'),
      screen: const AdminInfoEditScreen(),
    );
    expect(find.text('Info'), findsOneWidget);
    expect(find.text('Non trouvé'), findsOneWidget);
    await tester.runAsync(() => db.close());
  }, timeout: timeout);
}

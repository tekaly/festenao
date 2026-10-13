import 'package:festenao_admin_base_app/screen/admin_article_edit_screen_bloc_mixin.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_common/data/src/model/db_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

class _ProjectContext implements FestenaoAdminAppProjectContext {
  @override
  String get storageBucket => 'bucket';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DbBloc implements AdminAppProjectContextDbBloc {
  final Database db;

  _DbBloc(this.db);

  @override
  FestenaoAdminAppProjectContext get projectContext => _ProjectContext();

  @override
  Future<Database> grabDatabase() async => db;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EventSaver with AdminArticleEditScreenBlocMixin<DbEvent> {
  @override
  final AdminAppProjectContextDbBloc dbBloc;

  _EventSaver(this.dbBloc);

  @override
  CvStoreRef<String, DbEvent> get articleStore => dbEventStoreRef;
}

void main() {
  initFestenaoDbBuilders();
  test('save keeps the fields not edited by the screen', () async {
    var db = await newDatabaseFactoryMemory().openDatabase('article.db');
    var ref = dbEventStoreRef.record('e1');
    await (ref.cv()
          ..name.v = 'name'
          ..squareImage.v = 'square'
          ..location.v = 'location'
          ..artists.v = ['a1'])
        .put(db);

    // What an edit screen builds from its form.
    var form = DbEvent()
      ..rawRef = ref.rawRef
      ..day.v = '2026-01-01'
      ..name.v = 'renamed'
      ..thumbnail.v = ''
      ..image.v = '';
    await _EventSaver(_DbBloc(db)).save(AdminArticleEditData(article: form));

    var event = (await ref.get(db))!;
    expect(event.name.v, 'renamed');
    expect(event.day.v, '2026-01-01');
    expect(event.squareImage.v, 'square');
    expect(event.location.v, 'location');
    expect(event.artists.v, ['a1']);
    await db.close();
  });
}

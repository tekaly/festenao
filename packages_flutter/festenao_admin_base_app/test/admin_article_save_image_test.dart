import 'dart:typed_data';

import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/screen/admin_article_edit_screen_bloc_mixin.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_common/data/src/model/db_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sembast/sembast_memory.dart';
import 'package:tkcms_admin_app/app/tkcms_admin_app.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

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

class _InfoSaver with AdminArticleEditScreenBlocMixin<DbInfo> {
  @override
  final AdminAppProjectContextDbBloc dbBloc;

  _InfoSaver(this.dbBloc);

  @override
  CvStoreRef<String, DbInfo> get articleStore => dbInfoStoreRef;
}

Uint8List _jpg(int width) =>
    img.encodeJpg(img.Image(width: width, height: width));

void main() {
  initFestenaoDbBuilders();
  test('a new image of a duplicated article never overwrites the image of its '
      'source', () async {
    // Memory storage for the upload.
    globalTkCmsAdminAppFirebaseContext = await initFirebaseServicesLocalMemory(
      projectId: 'test',
    ).init();
    globalFestenaoAppFirebaseContext = FestenaoAppFirebaseOptions(
      storageRootPath: 'app/test',
      firestoreRootPath: 'app/test',
      storageBucket: 'bucket',
    );
    var db = await newDatabaseFactoryMemory().openDatabase('content.db');
    // Info A and its image.
    await (dbImageStoreRef.record('info_A').cv()
          ..name.v = 'info_A.jpg'
          ..width.v = 100
          ..height.v = 100)
        .put(db);
    await (dbInfoStoreRef.record('A').cv()
          ..name.v = 'A'
          ..image.v = 'info_A'
          ..thumbnail.v = 'info_A')
        .put(db);
    // B, a duplicate of A (pointing to the image of A), gets a new image
    // and thumbnail.
    var b = dbInfoStoreRef.record('B').cv()
      ..name.v = 'B'
      ..image.v = 'info_A'
      ..thumbnail.v = 'info_A';
    await _InfoSaver(_DbBloc(db)).save(
      AdminArticleEditData(
        article: b,
        imageData: _jpg(8),
        thumbailData: _jpg(4),
      ),
    );

    var imageA = (await dbImageStoreRef.record('info_A').get(db))!;
    expect(imageA.width.v, 100, reason: 'the image of A was replaced');
    var savedB = (await dbInfoStoreRef.record('B').get(db))!;
    expect(savedB.image.v, 'info_B');
    expect(savedB.thumbnail.v, 'info_thumb_B');
    expect((await dbImageStoreRef.record('info_B').get(db))!.width.v, 8);
    expect((await dbImageStoreRef.record('info_thumb_B').get(db))!.width.v, 4);
    var infoA = (await dbInfoStoreRef.record('A').get(db))!;
    expect(infoA.image.v, 'info_A');
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 2)));
}

import 'dart:async';

import 'package:festenao_common/data/festenao_db.dart';

import 'admin_article_edit_screen_bloc_mixin.dart';
import 'admin_screen_bloc_mixin.dart';

/// Info edit screen bloc
class AdminInfoEditScreenBlocState {
  late final String? infoId;
  final DbInfo? info;

  AdminInfoEditScreenBlocState({String? infoId, this.info}) {
    this.infoId = infoId ?? info?.id;
  }
}

class AdminInfoEditScreenResult {
  final bool? deleted;

  AdminInfoEditScreenResult({this.deleted});
}

class AdminInfoEditScreenBloc
    extends AdminAppProjectScreenBlocBase<AdminInfoEditScreenBlocState>
    with AdminArticleEditScreenBlocMixin {
  final String? infoId;
  late final DbInfo? info;

  AdminInfoEditScreenBloc({
    DbInfo? info,
    required this.infoId,
    required super.projectContext,
  }) {
    if (infoId == null) {
      this.info = info;
      // Creation
      add(AdminInfoEditScreenBlocState(info: info));
    } else {
      () async {
        var db = await dbBloc.grabDatabase();
        this.info = info ??= (await dbInfoStoreRef.record(infoId!).get(db));

        add(AdminInfoEditScreenBlocState(info: info, infoId: infoId));
      }();
    }
  }

  Future<void> delete() async {
    var db = await dbBloc.grabDatabase();
    await dbInfoStoreRef.record(infoId!).delete(db);
  }

  @override
  CvStoreRef<String, DbArticle> get articleStore => dbInfoStoreRef;
}

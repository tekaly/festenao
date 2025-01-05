import 'dart:async';

import 'package:festenao_admin_base_app/sembast/booklets_db.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tekartik_app_flutter_bloc/bloc_provider.dart';

import 'admin_article_edit_screen_bloc_mixin.dart';

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

class AdminInfoEditScreenBloc extends BaseBloc
    with AdminArticleEditScreenBlocMixin {
  final String? infoId;
  late final DbInfo? info;
  final _state = BehaviorSubject<AdminInfoEditScreenBlocState>();

  ValueStream<AdminInfoEditScreenBlocState> get state => _state;

  AdminInfoEditScreenBloc({DbInfo? info, required this.infoId}) {
    if (infoId == null) {
      this.info = info;
      // Creation
      _state.add(AdminInfoEditScreenBlocState(info: info));
    } else {
      () async {
        var db = globalBookletsDb.db;
        this.info = info ??= (await dbInfoStoreRef.record(infoId!).get(db));

        _state.add(AdminInfoEditScreenBlocState(info: info, infoId: infoId));
      }();
    }
  }

  Future<void> delete() async {
    var db = globalBookletsDb.db;
    await dbInfoStoreRef.record(infoId!).delete(db);
  }

  @override
  void dispose() {
    _state.close();
    super.dispose();
  }

  @override
  CvStoreRef<String, DbArticle> get articleStore => dbInfoStoreRef;
}

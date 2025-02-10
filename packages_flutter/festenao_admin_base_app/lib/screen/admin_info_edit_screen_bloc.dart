import 'dart:async';

import 'package:festenao_admin_base_app/admin_app/admin_app_context_db_bloc.dart';
import 'package:festenao_admin_base_app/admin_app/admin_app_project_context.dart';

import 'package:festenao_common/data/festenao_db.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';

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

class AdminInfoEditScreenBloc
    extends AutoDisposeStateBaseBloc<AdminInfoEditScreenBlocState>
    with AdminArticleEditScreenBlocMixin {
  final FestenaoAdminAppProjectContext projectContext;
  @override
  late final dbBloc = audiAddDisposable(
      AdminAppProjectContextDbBloc(projectContext: projectContext));
  final String? infoId;
  late final DbInfo? info;
  final _state = BehaviorSubject<AdminInfoEditScreenBlocState>();

  AdminInfoEditScreenBloc(
      {DbInfo? info, required this.infoId, required this.projectContext}) {
    if (infoId == null) {
      this.info = info;
      // Creation
      _state.add(AdminInfoEditScreenBlocState(info: info));
    } else {
      () async {
        var db = await dbBloc.grabDatabase();
        this.info = info ??= (await dbInfoStoreRef.record(infoId!).get(db));

        _state.add(AdminInfoEditScreenBlocState(info: info, infoId: infoId));
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

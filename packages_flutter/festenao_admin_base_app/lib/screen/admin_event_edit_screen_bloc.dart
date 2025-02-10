import 'dart:async';

import 'package:festenao_admin_base_app/screen/admin_screen_bloc_mixin.dart';
import 'package:festenao_common/data/festenao_db.dart';

import 'admin_article_edit_screen_bloc_mixin.dart';

class AdminEventEditScreenBlocState {
  late final String? eventId;
  final DbEvent? event;

  AdminEventEditScreenBlocState({String? eventId, this.event}) {
    this.eventId = eventId ?? ((event?.hasId ?? false) ? event?.id : null);
  }
}

class AdminEventEditScreenParam {
  /// Template
  final DbEvent? event;

  AdminEventEditScreenParam({this.event});
}

class AdminEventEditScreenResult {
  final bool? deleted;

  AdminEventEditScreenResult({this.deleted});
}

class AdminEventEditScreenBloc
    extends AdminAppProjectScreenBlocBase<AdminEventEditScreenBlocState>
    with AdminArticleEditScreenBlocMixin {
  final String? eventId;
  final AdminEventEditScreenParam? param;

  AdminEventEditScreenBloc(
      {required this.eventId,
      required this.param,
      required super.projectContext}) {
    if (eventId == null) {
      // Creation
      add(AdminEventEditScreenBlocState(event: param?.event));
    } else {
      () async {
        var db = await projectDb;
        var event = (await dbEventStoreRef.record(eventId!).get(db));

        add(AdminEventEditScreenBlocState(event: event, eventId: eventId));
      }();
    }
  }

  Future<void> delete() async {
    var db = await projectDb;
    await dbEventStoreRef.record(eventId!).delete(db);
  }

  @override
  CvStoreRef<String, DbArticle> get articleStore => dbEventStoreRef;
}

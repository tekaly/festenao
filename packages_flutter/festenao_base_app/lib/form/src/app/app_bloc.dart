import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_audi.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/festenao_sembast.dart';
import 'package:festenao_common/form/tk_form_db.dart';
//import 'package:tekartik_app_flutter_sembast/sembast.dart';

import 'package:tekartik_common_utils/iterable_utils.dart';

class AppBloc {
  final DatabaseFactory databaseFactory;
  late LocalDatabase localDatabase;

  final AppFlavorContext appOptions;

  // Specific for each app and if local
  String get packageName => 'com.fuf.${uniqueAppName()}';

  String uniqueAppName([String name = '']) {
    // ignore: unnecessary_string_interpolations
    var prefix = '${appOptions.app}';
    if (appOptions.local) {
      prefix = '$prefix-local';
    }
    name = '$prefix${name.isNotEmpty ? '-$name' : ''}';

    return name;
  }

  /// Typically set after the start page
  String? surveyIdOrNull;

  String get surveyId => surveyIdOrNull!;

  AppBloc({
    required this.databaseFactory,
    required this.appOptions,
    String? surveyId,
  }) {
    surveyIdOrNull = surveyId;
  }

  Future<void> init() async {
    /*
    apiService = FufFormApiServiceV1(
      local: appOptions.local,
      flavorContext: appOptions.flavorContext,
      httpClientFactory: httpClientFactoryUniversal,
    );
    await apiService.initClient();*/
    localDatabase = LocalDatabase(databaseFactory);
    await localDatabase.init();

    () async {
      /*
      // Lazy loading
      if (surveyIdOrNull != null) {
        var response = await apiService.getSurveyInfo(
          FufFormApiGetSurveyInfoRequest()
            ..surveyId.v = surveyId
            ..app.v = appOptions.app,
        );*/
      var dbSurvey = DbSurvey()..lastUsedTimestamp.v = DbTimestamp.now();
      //..details.v = response.details.v;
      await dbSurveyStore
          .record(surveyId)
          .put(localDatabase.database, dbSurvey);
    }().unawait();
  }

  late final ValueStream<DbSurvey> dbSurveyVS = dbSurveyStore
      .record(surveyId)
      .onRecord(localDatabase.database)
      .whereNotNull()
      .toBroadcastValueStream();

  DbTimestamp? surveyStartTimestamp;
  late CvSurveyAnswers surveyAnswers;
  void startSurvey() {
    surveyStartTimestamp = DbTimestamp.now();
    surveyAnswers = CvSurveyAnswers()..list.v = [];
  }

  void addAnswer(CvSurveyAnswer? answer) {
    // ignore: avoid_print
    print('addAnswer: $answer');
    if (answer != null) {
      surveyAnswers.list.v!.removeWhere(
        (element) => element.id.v == answer.id.v,
      );
      surveyAnswers.list.v!.add(answer);
    }
  }

  CvSurveyAnswer? getAnswer(String id) {
    return surveyAnswers.list.v!.firstWhereOrNull(
      (element) => element.id.v == id,
    );
  }
}

late AppBloc gAppBloc;

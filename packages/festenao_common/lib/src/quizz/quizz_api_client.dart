import 'package:festenao_common/festenao_api.dart';

import 'model/quizz_api_models.dart';
import 'quizz_constant.dart';

/// The quizz api of a project, on top of any api service
/// (`FestenaoApiService` or the one of an app built on festenao): the player
/// side of `QuizzServerHandler`.
class QuizzApiClient {
  /// The api service used.
  final TkCmsApiServiceBaseV2 apiService;

  /// The project id.
  final String projectId;

  /// The data id ([quizzDefaultDataId] by default).
  final String dataId;

  /// Creates the quizz api client of a project.
  QuizzApiClient({
    required this.apiService,
    required this.projectId,
    String? dataId,
  }) : dataId = dataId ?? quizzDefaultDataId {
    initQuizzApiBuilders();
  }

  /// Sends a player result, the project and data ids being set from this
  /// client.
  ///
  /// Returns the player id, the same one when the same result is sent twice.
  Future<ApiQuizzSendResultResult> sendQuizResult(
    ApiQuizzSendResultQuery query,
  ) async {
    query
      ..projectId.v = projectId
      ..dataId.v = dataId;
    return await apiService.getApiResult<ApiQuizzSendResultResult>(
      ApiRequest(command: apiCommandQuizzSendResult)..setQuery(query),
    );
  }
}

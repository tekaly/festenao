import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';

/// Command name for reading the plan of a user in an app (their create
/// limits, whether they are blocked): their own, or anyone's for an app
/// admin.
const festenaoUserPlanGetCommand = 'user-plan/get';

/// Command name for changing the plan of a user in an app (app admins).
const festenaoUserPlanSetCommand = 'user-plan/set';

/// The collection of the users' plans in `app/<app>`, server-only.
const festenaoUserPlanCollectionId = 'user_plan';

/// The collection of the creators of the entities in `app/<app>`,
/// server-only: `creator/<entityType>/entity_id/<entityId>`.
const festenaoEntityCreatorCollectionId = 'creator';

/// `app/<app>/user_plan/<userId>`: the plans of the users of [app], read and
/// written by the server only (no client rule).
CvCollectionReference<FsFestenaoUserPlan> festenaoUserPlanCollection(
  String app,
) =>
    fsAppRoot(app).collection<FsFestenaoUserPlan>(festenaoUserPlanCollectionId);

/// `app/<app>/creator/<entityType>/entity_id/<entityId>`: who created the
/// entities of [entityType] of [app] through the api, read and written by
/// the server only.
CvCollectionReference<FsFestenaoEntityCreator> festenaoEntityCreatorCollection(
  String app,
  String entityType,
) => fsAppRoot(app)
    .collection<CvFirestoreDocument>(festenaoEntityCreatorCollectionId)
    .doc(entityType)
    .collection<FsFestenaoEntityCreator>('entity_id');

/// What the app admins set for a user, shared by its Firestore document and
/// the api.
mixin FestenaoUserPlanMixin implements CvModel {
  /// The entities they may create by entity type (`project`, `playlist`):
  /// the handler's default for a type absent or null.
  final createLimits = CvField<Map>('createLimits');

  /// Blocked: the server refuses their commands (an app admin is never
  /// blocked).
  final blocked = CvField<bool>('blocked');

  /// Why, for the app admins.
  final blockedReason = CvField<String>('blockedReason');

  /// The app admin who changed it last.
  final updatedBy = CvField<String>('updatedBy');

  /// The limit of [entityType], null for the default.
  int? createLimitOf(String entityType) =>
      (createLimits.v?[entityType] as num?)?.toInt();

  /// The plan fields.
  CvFields get userPlanFields => [
    createLimits,
    blocked,
    blockedReason,
    updatedBy,
  ];
}

/// The plan of a user in an app, its id the user's.
class FsFestenaoUserPlan extends CvFirestoreDocumentBase
    with FestenaoUserPlanMixin {
  /// When it was changed last.
  final updated = CvField<Timestamp>('updated');

  @override
  CvFields get fields => [...userPlanFields, updated];
}

/// Who created an entity, its id the entity's.
class FsFestenaoEntityCreator extends CvFirestoreDocumentBase {
  /// The user who created it.
  final userId = CvField<String>('userId');

  /// When.
  final created = CvField<Timestamp>('created');

  @override
  CvFields get fields => [userId, created];
}

/// [festenaoUserPlanGetCommand] query.
class FestenaoUserPlanGetApiQuery extends ApiQuery {
  /// The user, the signed in one when null.
  final userId = CvField<String>('userId');

  @override
  late final CvFields fields = [userId];
}

/// [festenaoUserPlanSetCommand] query: the fields set are changed, the
/// others kept (a null [createLimits] entry back to the default).
class FestenaoUserPlanSetApiQuery extends ApiQuery {
  /// The user.
  final userId = CvField<String>('userId');

  /// The create limits to change, by entity type (null: the default).
  final createLimits = CvField<Map>('createLimits');

  /// Blocked or not.
  final blocked = CvField<bool>('blocked');

  /// Why.
  final blockedReason = CvField<String>('blockedReason');

  @override
  late final CvFields fields = [userId, createLimits, blocked, blockedReason];
}

/// [festenaoUserPlanGetCommand] and [festenaoUserPlanSetCommand] result.
class FestenaoUserPlanApiResult extends ApiResult with FestenaoUserPlanMixin {
  /// The user.
  final userId = CvField<String>('userId');

  /// Whether they are an app admin.
  final appAdmin = CvField<bool>('appAdmin');

  @override
  late final CvFields fields = [userId, ...userPlanFields, appAdmin];
}

var _buildersInitialized = false;

/// Registers the user plan models (idempotent).
void initFestenaoUserPlanApiBuilders() {
  if (_buildersInitialized) {
    return;
  }
  _buildersInitialized = true;
  initTkCmsApiBuilders();
  cvAddConstructors([
    FsFestenaoUserPlan.new,
    FsFestenaoEntityCreator.new,
    FestenaoUserPlanGetApiQuery.new,
    FestenaoUserPlanSetApiQuery.new,
    FestenaoUserPlanApiResult.new,
  ]);
}

/// The user plan commands, for the app and its admin console.
class FestenaoUserPlanApiClient {
  /// The api service of the app's server.
  final TkCmsApiServiceBaseV2 apiService;

  /// Creates the client.
  FestenaoUserPlanApiClient({required this.apiService}) {
    initFestenaoUserPlanApiBuilders();
  }

  /// The plan of [userId], the signed in user's by default.
  Future<FestenaoUserPlanApiResult> get({String? userId}) =>
      apiService.getApiResult<FestenaoUserPlanApiResult>(
        ApiRequest(command: festenaoUserPlanGetCommand)
          ..setQuery(FestenaoUserPlanGetApiQuery()..userId.setValue(userId)),
      );

  /// Changes the plan of a user (app admins).
  Future<FestenaoUserPlanApiResult> set(FestenaoUserPlanSetApiQuery query) =>
      apiService.getApiResult<FestenaoUserPlanApiResult>(
        ApiRequest(command: festenaoUserPlanSetCommand)..setQuery(query),
      );
}

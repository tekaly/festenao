import 'package:festenao_common/api/festenao_api_user_plan.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// The users' plans of the apps a server serves (`app/<app>/user_plan`):
/// their create limits by entity type (read by the entity handlers with a
/// create limit) and whether they are blocked, set by the app admins
/// ([festenaoUserPlanSetCommand]).
///
/// [requireNotBlocked] refuses the commands of a blocked user: a server calls
/// it first in its `onCommand` (the festenao projects server app does once
/// its `userPlanHandler` is set). It costs one read per command of a signed
/// in user.
class FestenaoUserPlanHandler implements FestenaoApiHandler {
  /// The apps whose plans it serves (`app/<app>`): a request names its app
  /// (the api service's), the first one when it names none.
  final List<String> apps;

  /// The firestore of the apps.
  final Firestore firestore;

  /// Creates the handler.
  FestenaoUserPlanHandler({required this.apps, required this.firestore})
    : assert(apps.isNotEmpty) {
    initFestenaoUserPlanApiBuilders();
  }

  late final _appDb = TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsApp>(
    entityCollectionInfo: tkCmsFsAppCollectionInfo,
    firestore: firestore,
    rootDocument: null,
  );

  @override
  Future<ApiResult?> onCommandOrNull(ApiRequest apiRequest) async {
    switch (apiRequest.command.v) {
      case festenaoUserPlanGetCommand:
        return await onGetCommand(apiRequest);
      case festenaoUserPlanSetCommand:
        return await onSetCommand(apiRequest);
    }
    return null;
  }

  static Never _error(String code, String message) {
    throw (ApiError()
          ..code.v = code
          ..message.v = message
          ..noRetry.v = true)
        .exception();
  }

  static String _requireUserId(ApiRequest apiRequest) =>
      apiRequest.userId.v ??
      _error(HttpsErrorCode.unauthenticated, 'User not authenticated');

  /// A required id of a query, never a path.
  static String _requireId(CvField<String> field) {
    var value = field.v;
    if (value == null || value.isEmpty) {
      _error(HttpsErrorCode.invalidArgument, 'Missing ${field.name}');
    }
    if (!tkCmsIsValidDocumentId(value)) {
      _error(HttpsErrorCode.invalidArgument, 'Invalid ${field.name}');
    }
    return value;
  }

  /// The app of a request, null when it is not served.
  String? _appOrNull(ApiRequest apiRequest) {
    var app = apiRequest.app.v ?? apps.first;
    return apps.contains(app) ? app : null;
  }

  String _appOf(ApiRequest apiRequest) =>
      _appOrNull(apiRequest) ??
      _error(
        HttpsErrorCode.permissionDenied,
        'App ${apiRequest.app.v} not served',
      );

  /// An admin of the app entity of [app] (`access/app/entity_id/<app>`).
  Future<bool> isAppAdmin(String app, String userId) async {
    var access = await _appDb.fsEntityUserAccessRef(app, userId).get(firestore);
    return access.exists && access.isAdmin;
  }

  /// The plan of [userId] in [app], empty when none was set.
  Future<FsFestenaoUserPlan> planOf(String app, String userId) =>
      festenaoUserPlanCollection(app).doc(userId).get(firestore);

  /// Refuses the request of a blocked user (`permission-denied`), for an app
  /// it serves; an app admin is never blocked.
  Future<void> requireNotBlocked(ApiRequest apiRequest) async {
    var userId = apiRequest.userId.v;
    var app = _appOrNull(apiRequest);
    if (userId == null || app == null) {
      return;
    }
    var plan = await planOf(app, userId);
    if (plan.blocked.v == true && !await isAppAdmin(app, userId)) {
      _error(HttpsErrorCode.permissionDenied, 'User blocked');
    }
  }

  Future<FestenaoUserPlanApiResult> _resultOf(String app, String userId) async {
    var plan = await planOf(app, userId);
    return FestenaoUserPlanApiResult()
      ..userId.v = userId
      ..createLimits.v = plan.createLimits.v
      ..blocked.v = plan.blocked.v
      ..blockedReason.v = plan.blockedReason.v
      ..updatedBy.v = plan.updatedBy.v
      ..appAdmin.v = await isAppAdmin(app, userId);
  }

  /// Handles [festenaoUserPlanGetCommand]: their own, or anyone's for an app
  /// admin.
  Future<FestenaoUserPlanApiResult> onGetCommand(ApiRequest apiRequest) async {
    var app = _appOf(apiRequest);
    var callerId = _requireUserId(apiRequest);
    var query = apiRequest.query<FestenaoUserPlanGetApiQuery>();
    var userId = query.userId.v == null ? callerId : _requireId(query.userId);
    if (userId != callerId && !await isAppAdmin(app, callerId)) {
      _error(HttpsErrorCode.permissionDenied, 'Not an app admin');
    }
    return await _resultOf(app, userId);
  }

  /// Handles [festenaoUserPlanSetCommand] (app admins): the fields of the
  /// query that are set change, the others are kept.
  Future<FestenaoUserPlanApiResult> onSetCommand(ApiRequest apiRequest) async {
    var app = _appOf(apiRequest);
    var callerId = _requireUserId(apiRequest);
    if (!await isAppAdmin(app, callerId)) {
      _error(HttpsErrorCode.permissionDenied, 'Not an app admin');
    }
    var query = apiRequest.query<FestenaoUserPlanSetApiQuery>();
    var userId = _requireId(query.userId);
    var plan = await planOf(app, userId);
    if (query.createLimits.hasValue) {
      var limits = <String, Object?>{
        for (var MapEntry(:key, :value) in (plan.createLimits.v ?? {}).entries)
          '$key': value,
      };
      for (var MapEntry(:key, :value) in (query.createLimits.v ?? {}).entries) {
        if (value == null) {
          limits.remove(key);
        } else if (value is! int || value < 0) {
          _error(HttpsErrorCode.invalidArgument, 'Invalid limit of $key');
        } else {
          limits['$key'] = value;
        }
      }
      plan.createLimits.v = limits.isEmpty ? null : limits;
    }
    if (query.blocked.hasValue) {
      plan.blocked.v = query.blocked.v == true ? true : null;
      plan.blockedReason.v = plan.blocked.v == true
          ? query.blockedReason.v
          : null;
    }
    plan
      ..updatedBy.v = callerId
      ..updated.v = Timestamp.now();
    await festenaoUserPlanCollection(app).doc(userId).set(firestore, plan);
    return await _resultOf(app, userId);
  }
}

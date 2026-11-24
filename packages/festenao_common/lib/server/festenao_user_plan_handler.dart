import 'package:festenao_common/api/festenao_api_user_plan.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/slug/project_slug.dart';
import 'package:festenao_common/slug/slug.dart';
import 'package:festenao_common/slug/slug_registry.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// The users' plans of the apps a server serves (`app/<app>/user_plan`):
/// their create limits by entity type (read by the entity handlers with a
/// create limit), whether they are blocked, and their site plan (paid or
/// free, the projects with a public address, ads; [FestenaoSitePlan]), set
/// by the app admins ([festenaoUserPlanSetCommand]) and by the server for a
/// payment ([recordPayment]).
///
/// The public addresses (slugs) a user gives their projects through
/// [festenaoUserPlanClaimProjectSlugCommand] are counted in a server-only
/// usage record (`app/<app>/user_usage`), in the transaction that claims
/// the slug: a client cannot change the count, two claims at once cannot
/// both pass the limit.
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

  /// The database of the server, for the projects and their slugs (the
  /// slug commands answer `unimplemented` without it).
  final FestenaoFirestoreDatabase? database;

  /// What a free and a paying user get.
  final FestenaoSitePlanPolicy sitePlanPolicy;

  /// Creates the handler.
  FestenaoUserPlanHandler({
    required this.apps,
    required this.firestore,
    this.database,
    this.sitePlanPolicy = festenaoSitePlanPolicyDefault,
  }) : assert(apps.isNotEmpty) {
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
      case festenaoUserPlanClaimProjectSlugCommand:
        return await onClaimProjectSlugCommand(apiRequest);
      case festenaoUserPlanReleaseProjectSlugCommand:
        return await onReleaseProjectSlugCommand(apiRequest);
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

  /// What [userId] uses in [app], empty when nothing.
  Future<FsFestenaoUserUsage> usageOf(String app, String userId) =>
      festenaoUserUsageCollection(app).doc(userId).get(firestore);

  /// The site plan in effect of [userId] in [app] now.
  Future<FestenaoSitePlan> sitePlanOf(String app, String userId) async =>
      (await planOf(app, userId)).sitePlan(
        now: DateTime.now(),
        policy: sitePlanPolicy,
        appAdmin: await isAppAdmin(app, userId),
      );

  Future<FestenaoUserPlanApiResult> _resultOf(String app, String userId) async {
    var plan = await planOf(app, userId);
    var appAdmin = await isAppAdmin(app, userId);
    var sitePlan = plan.sitePlan(
      now: DateTime.now(),
      policy: sitePlanPolicy,
      appAdmin: appAdmin,
    );
    var usage = await usageOf(app, userId);
    return FestenaoUserPlanApiResult()
      ..userId.v = userId
      ..createLimits.v = plan.createLimits.v
      ..blocked.v = plan.blocked.v
      ..blockedReason.v = plan.blockedReason.v
      ..updatedBy.v = plan.updatedBy.v
      ..slugLimit.v = plan.slugLimit.v
      ..granted.v = plan.granted.v
      ..ads.v = plan.ads.v
      ..appAdmin.v = appAdmin
      ..paidUntil.v = sitePlan.paidUntil?.toUtc().toIso8601String()
      ..subscriptionId.v = plan.subscriptionId.v
      ..paid.v = sitePlan.paid
      ..inGrace.v = sitePlan.inGrace
      ..effectiveSlugLimit.v = sitePlan.slugLimit
      ..effectiveAds.v = sitePlan.ads
      ..slugProjectCount.v = usage.slugProjects.v?.length ?? 0;
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
    if (query.slugLimit.hasValue) {
      var limit = query.slugLimit.v;
      if (limit != null && limit < 0) {
        _error(HttpsErrorCode.invalidArgument, 'Invalid slugLimit');
      }
      plan.slugLimit.v = limit;
    }
    if (query.granted.hasValue) {
      plan.granted.v = query.granted.v == true ? true : null;
    }
    if (query.paidUntil.hasValue) {
      var text = query.paidUntil.v;
      if (text == null) {
        plan.paidUntil.v = null;
      } else {
        var date = DateTime.tryParse(text);
        if (date == null) {
          _error(HttpsErrorCode.invalidArgument, 'Invalid paidUntil');
        }
        plan.paidUntil.v = Timestamp.fromDateTime(date);
      }
    }
    if (query.ads.hasValue) {
      plan.ads.v = query.ads.v;
    }
    plan
      ..updatedBy.v = callerId
      ..updated.v = Timestamp.now();
    await festenaoUserPlanCollection(app).doc(userId).set(firestore, plan);
    return await _resultOf(app, userId);
  }

  /// Records a payment of [userId] in [app] (the payment webhook, never a
  /// client): their plan paid until [paidUntil] by [subscriptionId], the
  /// other fields of their plan kept.
  Future<void> recordPayment(
    String app,
    String userId, {
    required DateTime paidUntil,
    String? subscriptionId,
  }) async {
    if (!apps.contains(app)) {
      throw ArgumentError.value(app, 'app', 'not served');
    }
    await festenaoUserPlanCollection(app)
        .doc(userId)
        .set(
          firestore,
          FsFestenaoUserPlan()
            ..paidUntil.v = Timestamp.fromDateTime(paidUntil)
            ..subscriptionId.v = subscriptionId
            ..updated.v = Timestamp.now(),
          SetOptions(merge: true),
        );
  }

  FestenaoFirestoreDatabase _databaseOf(String app) =>
      database?.copyWithAppId(app) ??
      _error(HttpsErrorCode.unimplemented, 'No projects database');

  /// The signed in user, an admin of the project of the query, and the
  /// project id.
  Future<(String, String, FestenaoFirestoreDatabase)> _projectAdminOf(
    ApiRequest apiRequest,
    String app,
  ) async {
    var userId = _requireUserId(apiRequest);
    var query = apiRequest.query<FestenaoUserPlanProjectSlugApiQuery>();
    var projectId = _requireId(query.projectId);
    var db = _databaseOf(app);
    var access = await db.projectDb
        .fsEntityUserAccessRef(projectId, userId)
        .get(firestore);
    if (!access.exists || !access.isAdmin) {
      _error(HttpsErrorCode.permissionDenied, 'Not an admin of the project');
    }
    return (userId, projectId, db);
  }

  /// Handles [festenaoUserPlanClaimProjectSlugCommand]: the signed in user,
  /// an admin of the project, gives it the public address of the query
  /// ([claimProjectSlug]).
  Future<FestenaoUserPlanApiResult> onClaimProjectSlugCommand(
    ApiRequest apiRequest,
  ) async {
    var app = _appOf(apiRequest);
    var (userId, projectId, _) = await _projectAdminOf(apiRequest, app);
    var slug = apiRequest.query<FestenaoUserPlanProjectSlugApiQuery>().slug.v;
    if (slug == null || slug.isEmpty) {
      _error(HttpsErrorCode.invalidArgument, 'Missing slug');
    }
    await claimProjectSlug(
      app: app,
      userId: userId,
      projectId: projectId,
      slug: slug,
    );
    return await _resultOf(app, userId);
  }

  /// Gives the project [projectId] of [app] the public address [slug] (its
  /// current one, an older one kept as an alias) for [userId], the caller
  /// having checked they are an admin of the project (the publish command
  /// of a festival, say).
  ///
  /// A project counts once in the slug limit of the user who claimed it
  /// first, whatever its slugs and whichever of its admins changes it
  /// later: changing its address takes no new place. In one transaction:
  /// who holds the project, the plan and usage of [userId] read, the limit
  /// checked, the slug claimed, the project counted.
  ///
  /// Throws an [ApiException]: `invalid-argument` for an invalid slug
  /// (checked before the limit), `resource-exhausted` past the limit,
  /// `already-exists` when another entity has the slug.
  Future<void> claimProjectSlug({
    required String app,
    required String userId,
    required String projectId,
    required String slug,
  }) async {
    if (!festenaoSlugOptionsDefault.isValid(slug)) {
      _error(HttpsErrorCode.invalidArgument, 'Invalid slug');
    }
    var db = _databaseOf(app);
    var appAdmin = await isAppAdmin(app, userId);
    var holderRef = festenaoSlugProjectCollection(app).doc(projectId);
    var planRef = festenaoUserPlanCollection(app).doc(userId);
    var usageRef = festenaoUserUsageCollection(app).doc(userId);
    try {
      await firestore.cvRunTransaction((txn) async {
        var holder = await txn.refGet(holderRef);
        var counted = holder.exists && holder.userId.v != null;
        List<String>? projects;
        if (!counted) {
          var plan = await txn.refGet(planRef);
          var usage = await txn.refGet(usageRef);
          projects = usage.slugProjects.v ?? const <String>[];
          var sitePlan = plan.sitePlan(
            now: DateTime.now(),
            policy: sitePlanPolicy,
            appAdmin: appAdmin,
          );
          if (!sitePlan.canClaimSlug(projects.length)) {
            _error(
              HttpsErrorCode.resourceExhausted,
              'Slug limit reached (${sitePlan.slugLimit})',
            );
          }
        }
        await db.txnSetProjectSlug(txn, projectId, slug);
        if (projects != null) {
          var now = Timestamp.now();
          txn.refSet(
            holderRef,
            FsFestenaoSlugProject()
              ..userId.v = userId
              ..claimed.v = now,
          );
          txn.refSet(
            usageRef,
            FsFestenaoUserUsage()
              ..slugProjects.v = {...projects, projectId}.toList()
              ..updated.v = now,
          );
        }
      });
    } on FestenaoSlugTakenException catch (_) {
      _error(HttpsErrorCode.alreadyExists, 'Slug taken');
    } on FestenaoSlugInvalidException catch (_) {
      _error(HttpsErrorCode.invalidArgument, 'Invalid slug');
    }
  }

  /// Handles [festenaoUserPlanReleaseProjectSlugCommand]: the signed in
  /// user, an admin of the project, takes its public addresses back
  /// ([releaseProjectSlug]).
  Future<FestenaoUserPlanApiResult> onReleaseProjectSlugCommand(
    ApiRequest apiRequest,
  ) async {
    var app = _appOf(apiRequest);
    var (userId, projectId, _) = await _projectAdminOf(apiRequest, app);
    await releaseProjectSlug(app: app, projectId: projectId);
    return await _resultOf(app, userId);
  }

  /// Takes the public addresses of the project [projectId] of [app] back
  /// (the caller checked the right to), freeing its place in the slug limit
  /// of the user holding it: in one transaction, the holder and their usage
  /// read, the registry entries and the project's slugs cleared, the place
  /// freed. Returns the slugs released.
  Future<List<String>> releaseProjectSlug({
    required String app,
    required String projectId,
  }) async {
    var db = _databaseOf(app);
    var holderRef = festenaoSlugProjectCollection(app).doc(projectId);
    return await firestore.cvRunTransaction((txn) async {
      var holder = await txn.refGet(holderRef);
      var holderId = holder.exists ? holder.userId.v : null;
      var usageRef = holderId == null
          ? null
          : festenaoUserUsageCollection(app).doc(holderId);
      var usage = usageRef == null ? null : await txn.refGet(usageRef);
      var released = await db.txnReleaseProjectSlugs(txn, projectId);
      if (holder.exists) {
        txn.refDelete(holderRef);
      }
      var projects = usage?.slugProjects.v ?? const <String>[];
      if (usageRef != null && projects.contains(projectId)) {
        var left = projects.where((id) => id != projectId).toList();
        txn.refSet(
          usageRef,
          FsFestenaoUserUsage()
            ..slugProjects.v = left.isEmpty ? null : left
            ..updated.v = Timestamp.now(),
        );
      }
      return released;
    });
  }
}

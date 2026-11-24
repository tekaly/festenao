import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';

/// Command name for reading the plan of a user in an app (their create
/// limits, whether they are blocked): their own, or anyone's for an app
/// admin.
const festenaoUserPlanGetCommand = 'user-plan/get';

/// Command name for changing the plan of a user in an app (app admins).
const festenaoUserPlanSetCommand = 'user-plan/set';

/// Command name for giving a project of the signed in user a public
/// address (a slug), counted against the slug limit of their plan
/// ([FestenaoSitePlan.slugLimit]): one transaction for the count, the
/// registry and the project.
const festenaoUserPlanClaimProjectSlugCommand = 'user-plan/claim-project-slug';

/// Command name for taking the public addresses of a project of the
/// signed in user back, freeing its place in their slug limit.
const festenaoUserPlanReleaseProjectSlugCommand =
    'user-plan/release-project-slug';

/// The collection of the users' plans in `app/<app>`, server-only.
const festenaoUserPlanCollectionId = 'user_plan';

/// The collection of what the users use in `app/<app>` (the projects
/// holding a slug they claimed), server-only: counted by the server in the
/// transaction that changes it, never by a client.
const festenaoUserUsageCollectionId = 'user_usage';

/// The collection of the projects holding a public address claimed through
/// the server in `app/<app>`, server-only: who holds its place.
const festenaoSlugProjectCollectionId = 'slug_project';

/// `app/<app>/slug_project/<projectId>`: the user whose slug limit a project
/// of [app] holding a public address counts in, read and written by the
/// server only (no client rule).
CvCollectionReference<FsFestenaoSlugProject> festenaoSlugProjectCollection(
  String app,
) => fsAppRoot(
  app,
).collection<FsFestenaoSlugProject>(festenaoSlugProjectCollectionId);

/// `app/<app>/user_usage/<userId>`: what the users of [app] use, read and
/// written by the server only (no client rule).
CvCollectionReference<FsFestenaoUserUsage> festenaoUserUsageCollection(
  String app,
) => fsAppRoot(
  app,
).collection<FsFestenaoUserUsage>(festenaoUserUsageCollectionId);

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

  /// The projects with a public address (a slug) they may have: the
  /// policy's limit of their plan, free or paid, when null
  /// ([FestenaoSitePlanPolicy]).
  final slugLimit = CvField<int>('slugLimit');

  /// The paid plan given by an app admin: no end, no payment.
  final granted = CvField<bool>('granted');

  /// Whether their public sites show ads: true on the free plan, false on
  /// the paid one when null.
  final ads = CvField<bool>('ads');

  /// The limit of [entityType], null for the default.
  int? createLimitOf(String entityType) =>
      (createLimits.v?[entityType] as num?)?.toInt();

  /// The plan fields.
  CvFields get userPlanFields => [
    createLimits,
    blocked,
    blockedReason,
    updatedBy,
    slugLimit,
    granted,
    ads,
  ];
}

/// The plan of a user in an app, its id the user's.
class FsFestenaoUserPlan extends CvFirestoreDocumentBase
    with FestenaoUserPlanMixin {
  /// When it was changed last.
  final updated = CvField<Timestamp>('updated');

  /// Until when their plan is paid, none if never: set by the server when
  /// a payment arrives (or by an app admin).
  final paidUntil = CvField<Timestamp>('paidUntil');

  /// The subscription paying it (Stripe), set by the server only.
  final subscriptionId = CvField<String>('subscriptionId');

  @override
  CvFields get fields => [
    ...userPlanFields,
    updated,
    paidUntil,
    subscriptionId,
  ];

  /// The plan in effect at [now] (see [festenaoSitePlanOf]).
  FestenaoSitePlan sitePlan({
    required DateTime now,
    FestenaoSitePlanPolicy policy = festenaoSitePlanPolicyDefault,
    bool appAdmin = false,
  }) => festenaoSitePlanOf(
    this,
    paidUntil: paidUntil.v?.toDateTime(),
    now: now,
    policy: policy,
    appAdmin: appAdmin,
  );
}

/// What a user uses in an app, its id the user's, server-only.
class FsFestenaoUserUsage extends CvFirestoreDocumentBase {
  /// The projects holding a public address (a slug) they claimed through
  /// the server ([festenaoUserPlanClaimProjectSlugCommand]): counted
  /// against their slug limit, one place per project whatever its slugs.
  final slugProjects = CvListField<String>('slugProjects');

  /// When it was changed last.
  final updated = CvField<Timestamp>('updated');

  @override
  CvFields get fields => [slugProjects, updated];
}

/// A project holding a public address claimed through the server, its id
/// the project's, server-only: whose slug limit it counts in (the admin who
/// claimed it first, whichever admin changes or releases it later).
class FsFestenaoSlugProject extends CvFirestoreDocumentBase {
  /// The user holding its place.
  final userId = CvField<String>('userId');

  /// When it was claimed.
  final claimed = CvField<Timestamp>('claimed');

  @override
  CvFields get fields => [userId, claimed];
}

/// What a free and a paying user get in an app, and how long a paid plan
/// lasts past its end. The defaults are proposals: one public address with
/// ads for free, several without ads once paid.
class FestenaoSitePlanPolicy {
  /// The projects with a public address of a free user.
  final int freeSlugLimit;

  /// The projects with a public address of a paying user.
  final int paidSlugLimit;

  /// How long a paid plan lasts past its `paidUntil` (a late renewal, a
  /// card to update) before the user is back to the free plan.
  final Duration grace;

  /// A policy of [freeSlugLimit], [paidSlugLimit] and [grace].
  const FestenaoSitePlanPolicy({
    this.freeSlugLimit = 1,
    this.paidSlugLimit = 10,
    this.grace = const Duration(days: 14),
  });
}

/// The default [FestenaoSitePlanPolicy].
const festenaoSitePlanPolicyDefault = FestenaoSitePlanPolicy();

/// The plan in effect for a user at a moment ([festenaoSitePlanOf]).
class FestenaoSitePlan {
  /// Paid: [FestenaoUserPlanMixin.granted], or [paidUntil] (plus the grace
  /// period) not reached.
  final bool paid;

  /// Past [paidUntil], within the grace period: still paid.
  final bool inGrace;

  /// Until when it is paid, null when never (or granted).
  final DateTime? paidUntil;

  /// The projects with a public address they may have, null for no limit
  /// (an app admin).
  final int? slugLimit;

  /// Whether their public sites show ads.
  final bool ads;

  /// A plan in effect.
  const FestenaoSitePlan({
    required this.paid,
    required this.inGrace,
    required this.paidUntil,
    required this.slugLimit,
    required this.ads,
  });

  /// Whether one more project may get a public address, [count] holding
  /// one already.
  bool canClaimSlug(int count) => slugLimit == null || count < slugLimit!;

  @override
  String toString() =>
      'FestenaoSitePlan(${paid ? 'paid' : 'free'}${inGrace ? ', grace' : ''}'
      ', slugs ${slugLimit ?? 'unlimited'}, ${ads ? 'ads' : 'no ads'})';
}

/// The plan in effect at [now] of the record [plan] (an empty record when
/// the user has none), [paidUntil] its end of payment: paid when granted or
/// before [paidUntil] plus the grace of [policy]; the slug limit set by an
/// app admin, else the policy's of the plan (none for an app admin); ads
/// as set, else on the free plan only.
FestenaoSitePlan festenaoSitePlanOf(
  FestenaoUserPlanMixin plan, {
  required DateTime? paidUntil,
  required DateTime now,
  FestenaoSitePlanPolicy policy = festenaoSitePlanPolicyDefault,
  bool appAdmin = false,
}) {
  var granted = plan.granted.v == true;
  var paying = paidUntil != null && now.isBefore(paidUntil.add(policy.grace));
  var paid = granted || paying;
  return FestenaoSitePlan(
    paid: paid,
    inGrace: !granted && paying && !now.isBefore(paidUntil),
    paidUntil: paidUntil,
    slugLimit: appAdmin
        ? null
        : plan.slugLimit.v ??
              (paid ? policy.paidSlugLimit : policy.freeSlugLimit),
    ads: plan.ads.v ?? !paid,
  );
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

  /// Their slug limit (null: the policy's).
  final slugLimit = CvField<int>('slugLimit');

  /// The paid plan given (null or false: not given).
  final granted = CvField<bool>('granted');

  /// Until when the plan is paid (ISO 8601), null for never.
  final paidUntil = CvField<String>('paidUntil');

  /// Ads on their sites (null: on the free plan only).
  final ads = CvField<bool>('ads');

  @override
  late final CvFields fields = [
    userId,
    createLimits,
    blocked,
    blockedReason,
    slugLimit,
    granted,
    paidUntil,
    ads,
  ];
}

/// [festenaoUserPlanClaimProjectSlugCommand] and
/// [festenaoUserPlanReleaseProjectSlugCommand] query.
class FestenaoUserPlanProjectSlugApiQuery extends ApiQuery {
  /// The project, its admin the signed in user.
  final projectId = CvField<String>('projectId');

  /// The slug to claim (its current one), unused to release.
  final slug = CvField<String>('slug');

  @override
  late final CvFields fields = [projectId, slug];
}

/// [festenaoUserPlanGetCommand] and [festenaoUserPlanSetCommand] result,
/// the plan in effect included ([FestenaoSitePlan]).
class FestenaoUserPlanApiResult extends ApiResult with FestenaoUserPlanMixin {
  /// The user.
  final userId = CvField<String>('userId');

  /// Whether they are an app admin.
  final appAdmin = CvField<bool>('appAdmin');

  /// Until when the plan is paid (ISO 8601), null for never.
  final paidUntil = CvField<String>('paidUntil');

  /// The subscription paying it, null for none.
  final subscriptionId = CvField<String>('subscriptionId');

  /// In effect: paid ([FestenaoSitePlan.paid]).
  final paid = CvField<bool>('paid');

  /// In effect: past [paidUntil], within the grace period.
  final inGrace = CvField<bool>('inGrace');

  /// In effect: the projects with a public address they may have, null for
  /// no limit.
  final effectiveSlugLimit = CvField<int>('effectiveSlugLimit');

  /// In effect: ads on their sites.
  final effectiveAds = CvField<bool>('effectiveAds');

  /// The projects holding a public address they claimed.
  final slugProjectCount = CvField<int>('slugProjectCount');

  /// Whether one more project may get a public address.
  bool get canClaimSlug =>
      effectiveSlugLimit.v == null ||
      (slugProjectCount.v ?? 0) < effectiveSlugLimit.v!;

  @override
  late final CvFields fields = [
    userId,
    ...userPlanFields,
    appAdmin,
    paidUntil,
    subscriptionId,
    paid,
    inGrace,
    effectiveSlugLimit,
    effectiveAds,
    slugProjectCount,
  ];
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
    FsFestenaoUserUsage.new,
    FsFestenaoSlugProject.new,
    FsFestenaoEntityCreator.new,
    FestenaoUserPlanGetApiQuery.new,
    FestenaoUserPlanSetApiQuery.new,
    FestenaoUserPlanProjectSlugApiQuery.new,
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

  /// Gives the project [projectId] of the signed in user the public
  /// address [slug], counted against their slug limit
  /// (`resource-exhausted` past it); their plan after it.
  Future<FestenaoUserPlanApiResult> claimProjectSlug({
    required String projectId,
    required String slug,
  }) => apiService.getApiResult<FestenaoUserPlanApiResult>(
    ApiRequest(command: festenaoUserPlanClaimProjectSlugCommand)..setQuery(
      FestenaoUserPlanProjectSlugApiQuery()
        ..projectId.v = projectId
        ..slug.v = slug,
    ),
  );

  /// Takes the public addresses of the project [projectId] back, freeing
  /// its place; their plan after it.
  Future<FestenaoUserPlanApiResult> releaseProjectSlug({
    required String projectId,
  }) => apiService.getApiResult<FestenaoUserPlanApiResult>(
    ApiRequest(
      command: festenaoUserPlanReleaseProjectSlugCommand,
    )..setQuery(FestenaoUserPlanProjectSlugApiQuery()..projectId.v = projectId),
  );
}

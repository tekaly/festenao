import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';

/// Client for managing Festenao CMS entities via API and Firestore.
///
/// [apiService] is any secured api client ([FestenaoApiService], or the
/// api service of an app built on festenao): only its `getApiResult` is
/// used.
class FestenaoApiFsEntityClient<T extends TkCmsFsEntity> {
  /// The API service used for CMS operations.
  final TkCmsApiServiceBaseV2 apiService;

  /// The entity access service for Firestore operations.
  /// firestore is not used as an accessor here but for data conversion
  final TkCmsFirestoreDatabaseServiceEntityAccess<T> entityAccess;

  /// Creates a new [FestenaoApiFsEntityClient] instance.
  ///
  /// The api models are generic on the entity type: the builders for [T] are
  /// registered here, whatever the app registered for its own entity types.
  FestenaoApiFsEntityClient({
    required this.apiService,
    required this.entityAccess,
  }) {
    initFestenaoFsEntityApiBuilders<T>();
  }

  /// Creates a new entity in the CMS and returns the created entity.
  Future<T> createEntity({required T entity, String? entityId}) async {
    var result = await apiService.getApiResult<FsCmsEntityCreateApiResult<T>>(
      ApiRequest(command: entityAccess.info.createCommand)..setQuery(
        FsCmsEntityCreateApiQuery<T>()
          ..entityId.setValue(entityId)
          ..data.v = entity.fsDataToJsonMap(),
      ),
    );
    var jsonMap = result.entity.v!;
    var resultEntityId = result.entityId.v!;

    return entityAccess.fsEntityRef(resultEntityId).cv()
      ..fsDataFromJsonMap(entityAccess.firestore, jsonMap);
  }

  /// Deletes an entity by [entityId]. Always succeeds (ok if not exists).
  Future<void> deleteEntity({required String entityId}) async {
    await apiService.getApiResult<FsCmsEntityDeleteApiResult<T>>(
      ApiRequest(command: entityAccess.info.deleteCommand)
        ..setQuery(FsCmsEntityDeleteApiQuery<T>()..entityId.setValue(entityId)),
    );
  }

  /// Purges an entity by [entityId]. Always succeeds (ok if not exists).
  Future<void> purgeEntity({required String entityId}) async {
    await apiService.getApiResult<FsCmsEntityPurgeApiResult<T>>(
      ApiRequest(command: entityAccess.info.purgeCommand)
        ..setQuery(FsCmsEntityPurgeApiQuery<T>()..entityId.setValue(entityId)),
    );
  }

  /// Joins an entity by [entityId] with the given [fsUserAccess]. Always succeeds (ok if not exists).
  Future<void> joinEntity({
    required String entityId,
    required TkCmsFsUserAccess fsUserAccess,
  }) async {
    await apiService.getApiResult<FsCmsEntityJoinApiResult<T>>(
      ApiRequest(command: entityAccess.info.joinCommand)..setQuery(
        FsCmsEntityJoinApiQuery<T>()
          ..entityId.setValue(entityId)
          ..access.v = fsUserAccess.fsDataToJsonMap(),
      ),
    );
  }

  /// Leaves an entity by [entityId]. Always succeeds (ok if not exists).
  Future<void> leaveEntity({required String entityId}) async {
    await apiService.getApiResult<FsCmsEntityLeaveApiResult<T>>(
      ApiRequest(command: entityAccess.info.leaveCommand)
        ..setQuery(FsCmsEntityLeaveApiQuery<T>()..entityId.setValue(entityId)),
    );
  }

  /// Creates a new invite for the entity. Returns the invite ID.
  ///
  /// When [email] is set, the invite is reserved to this email: only a user
  /// with this email can accept it (see [acceptEntityInvite]).
  Future<String> createEntityInvite({
    required String entityId,
    required TkCmsFsUserAccess fsUserAccess,
    String? email,
  }) async {
    var result = await apiService
        .getApiResult<FsCmsEntityCreateInviteApiResult<T>>(
          ApiRequest(command: entityAccess.info.createInviteCommand)..setQuery(
            FsCmsEntityCreateInviteApiQuery<T>()
              ..entityId.setValue(entityId)
              ..email.setValue(email)
              ..write.v = fsUserAccess.write.v
              ..admin.v = fsUserAccess.admin.v
              ..read.v = fsUserAccess.read.v,
          ),
        );
    return result.inviteId.v!;
  }

  /// Sends an addressed email invite for the entity: only the user whose
  /// verified email is [email] can accept it, after finding it with
  /// [checkEmailInvites]. Returns the invite id, the normalized email and
  /// whether the invite mail went (`mailSent`: false when the app sends none,
  /// or when it failed; the invite exists either way).
  ///
  /// The server only lets an admin of the entity or a global app admin do it
  /// (`permission-denied` otherwise), and refuses an access greater than the
  /// inviter's own. Inviting the same email again updates the pending invite
  /// (same id) and sends the mail again.
  Future<FsCmsEntityCreateEmailInviteApiResult<T>> sendEntityEmailInvite({
    required String entityId,
    required String email,
    required TkCmsFsUserAccess fsUserAccess,
  }) async {
    return await apiService
        .getApiResult<FsCmsEntityCreateEmailInviteApiResult<T>>(
          ApiRequest(command: entityAccess.info.createEmailInviteCommand)
            ..setQuery(
              FsCmsEntityCreateEmailInviteApiQuery<T>()
                ..entityId.setValue(entityId)
                ..email.setValue(email)
                ..write.v = fsUserAccess.write.v
                ..admin.v = fsUserAccess.admin.v
                ..read.v = fsUserAccess.read.v,
            ),
        );
  }

  /// [sendEntityEmailInvite], returning the invite ID only.
  Future<String> createEntityEmailInvite({
    required String entityId,
    required String email,
    required TkCmsFsUserAccess fsUserAccess,
  }) async => (await sendEntityEmailInvite(
    entityId: entityId,
    email: email,
    fsUserAccess: fsUserAccess,
  )).inviteId.v!;

  /// The email invites sent on the entity (admin side), most recent first,
  /// with what happened to them; optionally only the ones with [status]
  /// (`pending`, `accepted`, `discarded`).
  Future<List<TkCmsCvEmailInvite>> listEntityEmailInvites({
    required String entityId,
    String? status,
  }) async {
    var result = await apiService
        .getApiResult<FsCmsEntityListEmailInvitesApiResult<T>>(
          ApiRequest(command: entityAccess.info.listEmailInvitesCommand)
            ..setQuery(
              FsCmsEntityListEmailInvitesApiQuery<T>()
                ..entityId.setValue(entityId)
                ..status.setValue(status),
            ),
        );
    return result.invites.v ?? <TkCmsCvEmailInvite>[];
  }

  /// Deletes (revokes) an email invite of the entity (admin side), whatever
  /// its status.
  Future<void> deleteEntityEmailInvite({
    required String entityId,
    required String inviteId,
  }) async {
    await apiService.getApiResult<FsCmsEntityDeleteEmailInviteApiResult<T>>(
      ApiRequest(command: entityAccess.info.deleteEmailInviteCommand)..setQuery(
        FsCmsEntityDeleteEmailInviteApiQuery<T>()
          ..entityId.setValue(entityId)
          ..inviteId.setValue(inviteId),
      ),
    );
  }

  /// The pending email invites addressed to the signed in user, to call on
  /// app start and after login; optionally only the ones of [entityId].
  ///
  /// When the user email is not verified the result says so and lists no
  /// invite: none can be accepted until then.
  Future<FsCmsEntityCheckEmailInvitesApiResult<T>> checkEmailInvites({
    String? entityId,
  }) async {
    return await apiService
        .getApiResult<FsCmsEntityCheckEmailInvitesApiResult<T>>(
          ApiRequest(command: entityAccess.info.checkEmailInvitesCommand)
            ..setQuery(
              FsCmsEntityCheckEmailInvitesApiQuery<T>()
                ..entityId.setValue(entityId),
            ),
        );
  }

  /// Accepts an email invite addressed to the signed in user, whose email
  /// must be verified: the invite access is merged into the user's.
  Future<void> acceptEntityEmailInvite({
    required String entityId,
    required String inviteId,
  }) async {
    await apiService.getApiResult<FsCmsEntityAcceptEmailInviteApiResult<T>>(
      ApiRequest(command: entityAccess.info.acceptEmailInviteCommand)..setQuery(
        FsCmsEntityAcceptEmailInviteApiQuery<T>()
          ..entityId.setValue(entityId)
          ..inviteId.setValue(inviteId),
      ),
    );
  }

  /// Discards an email invite addressed to the signed in user, whose email
  /// must be verified: no access is granted, it cannot be accepted any more.
  Future<void> discardEntityEmailInvite({
    required String entityId,
    required String inviteId,
  }) async {
    await apiService.getApiResult<FsCmsEntityDiscardEmailInviteApiResult<T>>(
      ApiRequest(command: entityAccess.info.discardEmailInviteCommand)
        ..setQuery(
          FsCmsEntityDiscardEmailInviteApiQuery<T>()
            ..entityId.setValue(entityId)
            ..inviteId.setValue(inviteId),
        ),
    );
  }

  /// Accepts an invite for the entity.
  ///
  /// [email] is the current user email, it is required for an invite created
  /// with an email, it must match (case insensitive) or the call fails.
  Future<void> acceptEntityInvite({
    required String entityId,
    required String inviteId,
    String? email,
  }) async {
    await apiService.getApiResult<FsCmsEntityAcceptInviteApiResult<T>>(
      ApiRequest(command: entityAccess.info.acceptInviteCommand)..setQuery(
        FsCmsEntityAcceptInviteApiQuery<T>()
          ..entityId.setValue(entityId)
          ..inviteId.setValue(inviteId)
          ..email.setValue(email),
      ),
    );
  }

  /// Makes the entity public — readable by anyone, signed in or not — or
  /// private again. Returns whether it is public afterwards.
  ///
  /// The server only lets an admin of the entity do it, and the app may add
  /// a condition of its own (see `FestenaoEntityHandlerOptions.setPublicCheck`):
  /// the call fails with `permission-denied` otherwise.
  Future<bool> setEntityPublic({
    required String entityId,
    required bool public,
  }) async {
    var result = await apiService
        .getApiResult<FsCmsEntitySetPublicApiResult<T>>(
          ApiRequest(command: entityAccess.info.setPublicCommand)..setQuery(
            FsCmsEntitySetPublicApiQuery<T>()
              ..entityId.setValue(entityId)
              ..public.v = public,
          ),
        );
    return result.public.v ?? public;
  }

  /// Deletes an invite for the entity.
  Future<void> deleteEntityInvite({
    required String entityId,
    required String inviteId,
  }) async {
    await apiService.getApiResult<FsCmsEntityDeleteInviteApiResult<T>>(
      ApiRequest(command: entityAccess.info.deleteInviteCommand)..setQuery(
        FsCmsEntityDeleteInviteApiQuery<T>()
          ..entityId.setValue(entityId)
          ..inviteId.setValue(inviteId),
      ),
    );
  }
}

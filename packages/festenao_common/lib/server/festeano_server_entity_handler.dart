import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/server/festenao_email_invite_mailer.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_firebase_firestore/utils/json_utils.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// The condition an app may add to making an entity public, on top of being
/// an admin of the entity: an app level privilege of [userId], for instance.
/// Returning false refuses the command with `permission-denied`.
typedef FestenaoEntitySetPublicCheck =
    Future<bool> Function({required String userId, required String entityId});

/// Options for entity handler.
class FestenaoEntityHandlerOptions {
  /// Creates a new [FestenaoEntityHandlerOptions] with optional
  /// [customIdGenerator] and [setPublicCheck].
  const FestenaoEntityHandlerOptions({
    this.customIdGenerator,
    this.setPublicCheck,
    this.emailInviteMailer,
  });

  /// Custom ID generator function.
  final String Function()? customIdGenerator;

  /// The condition added to making an entity public (or private again), on
  /// top of being an admin of the entity; none by default.
  final FestenaoEntitySetPublicCheck? setPublicCheck;

  /// Sends the mail of a created email invite to its address; none by
  /// default, the invitee then only finds the invite in the app.
  final FestenaoEmailInviteMailer? emailInviteMailer;
}

/// Entity handler for Festenao entities.
class FestenaoEntityHandler<T extends TkCmsFsEntity>
    implements FestenaoApiHandler {
  /// Options for the handler.
  final FestenaoEntityHandlerOptions options;

  /// The server app.
  final TkCmsServerAppV2 app;

  /// Entity access for Firestore operations.
  final TkCmsFirestoreDatabaseServiceEntityAccess<T> entityAccess;

  /// Firestore instance.
  Firestore get firestore => entityAccess.firestore;

  String get _entityType => entityAccess.entityCollectionInfo.id;
  String get _collectionIdPrefix => _buildCollectionIdPrefix(_entityType);
  static String _buildCollectionIdPrefix(String entityCollectionId) =>
      '$entityCollectionId-';

  /// Checks if the [command] is an entity command for the given [entity].
  static bool isEntityCommand(String entity, String command) {
    return command.startsWith(festenaoEntityCommandPrefix(entity)) ||
        // compat v2
        command.startsWith(_buildCollectionIdPrefix(entity));
  }

  /// Creates a new [FestenaoEntityHandler] with the given [app], [entityAccess], and [options].
  FestenaoEntityHandler({
    required this.app,
    required this.entityAccess,
    this.options = const FestenaoEntityHandlerOptions(),
  });

  /// Handles the command if it's an entity command, otherwise returns null.
  @override
  Future<ApiResult?> onCommandOrNull(ApiRequest apiRequest) async {
    var command = apiRequest.command.v!;
    if (command == festenaoEntityCreateCommand(_entityType)) {
      return await onCreateCommand(apiRequest);
    } else if (command == festenaoEntityDeleteCommand(_entityType)) {
      return await onDeleteCommand(apiRequest);
    } else if (command == festenaoEntityPurgeCommand(_entityType)) {
      return await onPurgeCommand(apiRequest);
    } else if (command == festenaoEntityJoinCommand(_entityType)) {
      return await onJoinCommand(apiRequest);
    } else if (command == festenaoEntityLeaveCommand(_entityType)) {
      return await onLeaveCommand(apiRequest);
    } else if (command == festenaoEntityCreateInviteCommand(_entityType)) {
      return await onCreateInviteCommand(apiRequest);
    } else if (command == festenaoEntityAcceptInviteCommand(_entityType)) {
      return await onAcceptInviteCommand(apiRequest);
    } else if (command == festenaoEntityDeleteInviteCommand(_entityType)) {
      return await onDeleteInviteCommand(apiRequest);
    } else if (command == festenaoEntitySetPublicCommand(_entityType)) {
      return await onSetPublicCommand(apiRequest);
    } else if (command == festenaoEntityCreateEmailInviteCommand(_entityType)) {
      return await onCreateEmailInviteCommand(apiRequest);
    } else if (command == festenaoEntityListEmailInvitesCommand(_entityType)) {
      return await onListEmailInvitesCommand(apiRequest);
    } else if (command == festenaoEntityDeleteEmailInviteCommand(_entityType)) {
      return await onDeleteEmailInviteCommand(apiRequest);
    } else if (command == festenaoEntityCheckEmailInvitesCommand(_entityType)) {
      return await onCheckEmailInvitesCommand(apiRequest);
    } else if (command == festenaoEntityAcceptEmailInviteCommand(_entityType)) {
      return await onAcceptEmailInviteCommand(apiRequest);
    } else if (command ==
        festenaoEntityDiscardEmailInviteCommand(_entityType)) {
      return await onDiscardEmailInviteCommand(apiRequest);
    } else if (command == festenaoEntityGetUserInfoCommand(_entityType)) {
      return await onGetUserInfoCommand(apiRequest);
    }

    // compat
    if (command.startsWith(_collectionIdPrefix)) {
      var subCommand = command.substring(_collectionIdPrefix.length);
      switch (subCommand) {
        case festenaoCreateEntityCommand:
          return await onCreateCommand(apiRequest);
        case festenaoDeleteEntityCommand:
          return await onDeleteCommand(apiRequest);
        case festenaoPurgeEntityCommand:
          return await onPurgeCommand(apiRequest);
        case festenaoJoinEntityCommand:
          return await onJoinCommand(apiRequest);
        case festenaoLeaveEntityCommand:
          return await onLeaveCommand(apiRequest);
        case festenaoCreateInviteCommand:
        case 'createEntityInvite':
          return await onCreateInviteCommand(apiRequest);
        case festenaoAcceptInviteCommand:
        case 'acceptEntityInvite':
          return await onAcceptInviteCommand(apiRequest);
        case festenaoDeleteInviteCommand:
        case 'deleteEntityInvite':
          return await onDeleteInviteCommand(apiRequest);
        case festenaoSetEntityPublicCommand:
          return await onSetPublicCommand(apiRequest);
        default:
      }
    }
    return null;
  }

  /// Handles the create entity command.
  Future<FsCmsEntityCreateApiResult> onCreateCommand(
    ApiRequest apiRequest,
  ) async {
    {
      var query = apiRequest.query<FsCmsEntityCreateApiQuery<T>>()
        ..fromMap(apiRequest.data.v!);
      var userId = apiRequest.userId.v;
      if (userId == null) {
        throw (ApiError()
              ..code.v = apiErrorCodeInternal
              ..message.v = 'Missing userId'
              ..noRetry.v = true)
            .exception();
      }
      var entityId = query.entityId.v;
      //var entity = entityAccess.fsEntityRef(entityId).cv()..fsDataFromJsonMap(firestore, query.data.v!);
      var model = documentDataMapFromJsonMap(firestore, asModel(query.data.v!));
      var entity = model.cv<T>();
      entityId = await entityAccess.createEntity(
        userId: userId,
        entity: entity,
        entityId: entityId,
        customIdGenerator: options.customIdGenerator,
      );
      var path = entityAccess.fsEntityRef(entityId).path;
      var result = FsCmsEntityCreateApiResult()
        ..entityId.setValue(entityId)
        ..entity.v = entity.fsDataToJsonMap()
        ..path.v = path;
      return result;
    }
  }

  /// Handles the delete entity command.
  Future<FsCmsEntityDeleteApiResult> onDeleteCommand(
    ApiRequest apiRequest,
  ) async {
    {
      var query = apiRequest.query<FsCmsEntityDeleteApiQuery<T>>()
        ..fromMap(apiRequest.data.v!);
      var userId = apiRequest.userId.v;
      if (userId == null) {
        throw (ApiError()
              ..code.v = apiErrorCodeInternal
              ..message.v = 'Missing userId'
              ..noRetry.v = true)
            .exception();
      }
      var entityId = query.entityId.v;
      if (entityId == null) {
        throw (ApiError()
              ..code.v = apiErrorCodeInternal
              ..message.v = 'Missing entityId'
              ..noRetry.v = true)
            .exception();
      }
      await entityAccess.deleteEntity(entityId, userId: userId);

      var result = FsCmsEntityDeleteApiResult()..entityId.setValue(entityId);
      return result;
    }
  }

  /// Handles the purge entity command.
  Future<FsCmsEntityPurgeApiResult> onPurgeCommand(
    ApiRequest apiRequest,
  ) async {
    {
      var query = apiRequest.query<FsCmsEntityPurgeApiQuery<T>>()
        ..fromMap(apiRequest.data.v!);
      var userId = apiRequest.userId.v!;
      var entityId = query.entityId.v!;
      await entityAccess.purgeEntity(entityId, userId: userId);

      var result = FsCmsEntityPurgeApiResult()..entityId.setValue(entityId);
      return result;
    }
  }

  /// Handles the join entity command.
  Future<FsCmsEntityJoinApiResult> onJoinCommand(ApiRequest apiRequest) async {
    {
      var query = apiRequest.query<FsCmsEntityJoinApiQuery<T>>()
        ..fromMap(apiRequest.data.v!);
      var userId = apiRequest.userId.v!;
      var entityId = query.entityId.v!;
      var model = documentDataMapFromJsonMap(
        firestore,
        asModel(query.access.v!),
      );
      var userAccess = model.cv<TkCmsFsUserAccess>();
      await entityAccess.joinEntity(
        entityId: entityId,
        userId: userId,
        userAccess: userAccess,
      );

      var result = FsCmsEntityJoinApiResult()..entityId.setValue(entityId);
      return result;
    }
  }

  /// Handles the leave entity command.
  Future<FsCmsEntityLeaveApiResult> onLeaveCommand(
    ApiRequest apiRequest,
  ) async {
    {
      var query = apiRequest.query<FsCmsEntityLeaveApiQuery<T>>()
        ..fromMap(apiRequest.data.v!);
      var userId = apiRequest.userId.v!;
      var entityId = query.entityId.v!;
      await entityAccess.leaveEntity(entityId, userId: userId);

      var result = FsCmsEntityLeaveApiResult()..entityId.setValue(entityId);
      return result;
    }
  }

  /// Handles the create invite command.
  Future<FsCmsEntityCreateInviteApiResult<T>> onCreateInviteCommand(
    ApiRequest apiRequest,
  ) async {
    var query = apiRequest.query<FsCmsEntityCreateInviteApiQuery<T>>()
      ..fromMap(apiRequest.data.v!);
    var userId = apiRequest.userId.v;
    if (userId == null) {
      throw (ApiError()
            ..code.v = apiErrorCodeInternal
            ..message.v = 'Missing userId'
            ..noRetry.v = true)
          .exception();
    }
    var entityId = query.entityId.v!;
    var email = tkCmsNormalizeInviteEmail(query.email.v);
    var userAccess = TkCmsCvUserAccess()..copyAccessFrom(query);
    var fsEntity = await entityAccess.fsEntityCollectionRef
        .doc(entityId)
        .get(firestore);
    userAccess.fixAccess();
    var id = await entityAccess.createInviteEntity(
      userId: userId,
      entityId: entityId,
      userAccess: userAccess,
      entity: fsEntity,
      email: email,
    );
    return FsCmsEntityCreateInviteApiResult<T>()
      ..inviteId.v = id
      ..email.setValue(email);
  }

  /// Handles the accept invite command.
  Future<FsCmsEntityAcceptInviteApiResult<T>> onAcceptInviteCommand(
    ApiRequest apiRequest,
  ) async {
    var query = apiRequest.query<FsCmsEntityAcceptInviteApiQuery<T>>()
      ..fromMap(apiRequest.data.v!);
    var userId = apiRequest.userId.v;
    if (userId == null) {
      throw (ApiError()
            ..code.v = apiErrorCodeInternal
            ..message.v = 'Missing userId'
            ..noRetry.v = true)
          .exception();
    }
    var entityId = query.entityId.v!;
    var inviteId = query.inviteId.v!;
    // The email comes from the client (the api request only carries a
    // verified userId), it is checked against the invite email, if any.
    var email = tkCmsNormalizeInviteEmail(query.email.v);
    await entityAccess.acceptInviteEntity(
      userId: userId,
      inviteId: inviteId,
      entityId: entityId,
      email: email,
    );
    return FsCmsEntityAcceptInviteApiResult<T>()
      ..inviteId.v = inviteId
      ..email.setValue(email);
  }

  /// Handles the delete invite command.
  Future<FsCmsEntityDeleteInviteApiResult<T>> onDeleteInviteCommand(
    ApiRequest apiRequest,
  ) async {
    var query = apiRequest.query<FsCmsEntityDeleteInviteApiQuery<T>>()
      ..fromMap(apiRequest.data.v!);
    var userId = apiRequest.userId.v;
    if (userId == null) {
      throw (ApiError()
            ..code.v = apiErrorCodeInternal
            ..message.v = 'Missing userId'
            ..noRetry.v = true)
          .exception();
    }
    var entityId = query.entityId.v!;
    var inviteId = query.inviteId.v!;
    await entityAccess.deleteInviteEntity(
      inviteId: inviteId,
      entityId: entityId,
    );
    return FsCmsEntityDeleteInviteApiResult<T>()..inviteId.v = inviteId;
  }

  /// Handles the set public command: makes the entity readable by anyone
  /// (its `public_access/public` flag, see
  /// [TkCmsFirestoreDatabaseServiceEntityAccess.setEntityPublic]) or private
  /// again.
  ///
  /// Only an admin of the entity may do it, and the app may add a condition
  /// of its own ([FestenaoEntityHandlerOptions.setPublicCheck]); both refuse
  /// with `permission-denied`. Opening an entity to signed out visitors is
  /// never something a client can do on its own: no rule lets it write the
  /// flag.
  Future<FsCmsEntitySetPublicApiResult<T>> onSetPublicCommand(
    ApiRequest apiRequest,
  ) async {
    var query = apiRequest.query<FsCmsEntitySetPublicApiQuery<T>>()
      ..fromMap(apiRequest.data.v!);
    var userId = apiRequest.userId.v;
    if (userId == null) {
      throw (ApiError()
            ..code.v = HttpsErrorCode.unauthenticated
            ..message.v = 'User not authenticated'
            ..noRetry.v = true)
          .exception();
    }
    var entityId = query.entityId.v;
    if (entityId == null) {
      throw (ApiError()
            ..code.v = apiErrorCodeInternal
            ..message.v = 'Missing entityId'
            ..noRetry.v = true)
          .exception();
    }
    var public = query.public.v ?? false;
    var userAccess = await entityAccess
        .fsEntityUserAccessRef(entityId, userId)
        .get(firestore);
    if (!userAccess.exists || userAccess.admin.v != true) {
      throw (ApiError()
            ..code.v = HttpsErrorCode.permissionDenied
            ..message.v = 'Not an admin of this entity'
            ..noRetry.v = true)
          .exception();
    }
    var check = options.setPublicCheck;
    if (check != null && !await check(userId: userId, entityId: entityId)) {
      throw (ApiError()
            ..code.v = HttpsErrorCode.permissionDenied
            ..message.v = 'Not allowed to make this entity public'
            ..noRetry.v = true)
          .exception();
    }
    await entityAccess.setEntityPublic(entityId, public: public);
    return FsCmsEntitySetPublicApiResult<T>()
      ..entityId.setValue(entityId)
      ..public.v = public;
  }

  // Email invites (addressed, `TkCmsFsEmailInvite`): admin only data, every
  // access goes through the commands below (festenao `doc/invite_by_email.md`).

  /// The app entity access, for the global app admin check.
  late final _appEntityAccess =
      TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsApp>(
        entityCollectionInfo: tkCmsFsAppCollectionInfo,
        firestore: firestore,
      );

  /// The user id of the caller, set by the callable transport only.
  String _requireUserId(ApiRequest apiRequest) {
    var userId = apiRequest.userId.v;
    if (userId == null) {
      throw (ApiError()
            ..code.v = HttpsErrorCode.unauthenticated
            ..message.v = 'User not authenticated'
            ..noRetry.v = true)
          .exception();
    }
    return userId;
  }

  /// A required query field, neither null nor empty (an empty id would
  /// otherwise reach Firestore as an invalid document path).
  String _requireField(CvField<String> field) {
    var value = field.v;
    if (value == null || value.isEmpty) {
      throw (ApiError()
            ..code.v = HttpsErrorCode.invalidArgument
            ..message.v = 'Missing ${field.name}'
            ..noRetry.v = true)
          .exception();
    }
    return value;
  }

  /// The auth record of a user, for its email and whether it is verified.
  Future<UserRecord> _requireUser(String userId) async {
    var auth = app.firebaseContext.authOrNull;
    if (auth == null) {
      throw (ApiError()
            ..code.v = apiErrorCodeInternal
            ..message.v = 'No auth service'
            ..noRetry.v = true)
          .exception();
    }
    var user = await auth.getUser(userId);
    if (user == null) {
      throw (ApiError()
            ..code.v = HttpsErrorCode.notFound
            ..message.v = 'User $userId not found'
            ..noRetry.v = true)
          .exception();
    }
    return user;
  }

  /// The normalized verified email of the caller: an email invite is only
  /// accepted or discarded by the user that owns the address.
  Future<String> _requireVerifiedEmail(String userId) async {
    var user = await _requireUser(userId);
    var email = tkCmsNormalizeInviteEmail(user.email);
    if (email == null || !user.emailVerified) {
      throw (ApiError()
            ..code.v = HttpsErrorCode.failedPrecondition
            ..message.v = 'A verified email is required'
            ..noRetry.v = true)
          .exception();
    }
    return email;
  }

  /// True when [userId] is an admin of the entity.
  Future<bool> _isEntityAdmin(String entityId, String userId) async {
    var access = await entityAccess
        .fsEntityUserAccessRef(entityId, userId)
        .get(firestore);
    return access.exists && access.isAdmin;
  }

  /// The app id of the server, whose app entity holds the global admins;
  /// null for a server without one (then only entity admins exist).
  String? get _appId {
    var app = this.app;
    return app is TkAppCmsServerAppBase ? app.appFlavorContext.app : null;
  }

  /// True when [userId] is an admin of the app entity of this server
  /// (`access/app/entity_id/<appId>/user_access/<userId>`, admins are per
  /// flavor).
  Future<bool> _isAppAdmin(String userId) async {
    var appId = _appId;
    if (appId == null) {
      return false;
    }
    var access = await _appEntityAccess
        .fsEntityUserAccessRef(appId, userId)
        .get(firestore);
    return access.exists && access.isAdmin;
  }

  /// Only an admin of the entity or an app admin manages its email invites;
  /// `permission-denied` otherwise. Returns true for an app admin that is
  /// not an admin of the entity (the access escalation check does not apply
  /// to them).
  Future<bool> _requireEmailInviteAdmin(String entityId, String userId) async {
    if (await _isEntityAdmin(entityId, userId)) {
      return false;
    }
    if (await _isAppAdmin(userId)) {
      return true;
    }
    throw (ApiError()
          ..code.v = HttpsErrorCode.permissionDenied
          ..message.v = 'Not an admin of this entity'
          ..noRetry.v = true)
        .exception();
  }

  /// Check that the email invite [inviteId] exists and belongs to [entityId]
  /// (the invitee commands name both); `not-found` otherwise.
  Future<void> _checkEntityEmailInvite(String entityId, String inviteId) async {
    var invite = await entityAccess.fsEmailInviteRef(inviteId).get(firestore);
    if (!invite.exists || invite.entityId.v != entityId) {
      throw (ApiError()
            ..code.v = HttpsErrorCode.notFound
            ..message.v = 'Email invite $inviteId not found'
            ..noRetry.v = true)
          .exception();
    }
  }

  /// Handles the create email invite command (entity admin or app admin):
  /// an invite only the user with this verified email can accept, see
  /// [TkCmsFirestoreDatabaseServiceEntityAccess.createEmailInviteEntity].
  Future<FsCmsEntityCreateEmailInviteApiResult<T>> onCreateEmailInviteCommand(
    ApiRequest apiRequest,
  ) async {
    var query = apiRequest.query<FsCmsEntityCreateEmailInviteApiQuery<T>>()
      ..fromMap(apiRequest.data.v!);
    var userId = _requireUserId(apiRequest);
    var entityId = _requireField(query.entityId);
    var email = tkCmsNormalizeInviteEmail(query.email.v);
    if (email == null) {
      throw (ApiError()
            ..code.v = HttpsErrorCode.invalidArgument
            ..message.v = 'Missing email'
            ..noRetry.v = true)
          .exception();
    }
    var isAppAdmin = await _requireEmailInviteAdmin(entityId, userId);
    var userAccess = TkCmsCvUserAccess()..copyAccessFrom(query);
    var inviteId = await entityAccess.createEmailInviteEntity(
      userId: userId,
      entityId: entityId,
      email: email,
      userAccess: userAccess,
      skipAccessCheck: isAppAdmin,
    );
    var mailSent = false;
    var mailer = options.emailInviteMailer;
    if (mailer != null && mailer.enabled) {
      mailSent = await _sendEmailInviteMail(
        mailer,
        userId: userId,
        inviteId: inviteId,
      );
    }
    return FsCmsEntityCreateEmailInviteApiResult<T>()
      ..inviteId.v = inviteId
      ..email.v = email
      ..mailSent.v = mailSent;
  }

  /// Sends the mail of the created invite [inviteId], true when it went.
  ///
  /// A failure is logged, not an error of the command: the invite exists,
  /// the invitee finds it in the app, the inviter is told the mail did not go
  /// (`mailSent`).
  Future<bool> _sendEmailInviteMail(
    FestenaoEmailInviteMailer mailer, {
    required String userId,
    required String inviteId,
  }) async {
    try {
      var invite = await entityAccess.fsEmailInviteRef(inviteId).get(firestore);
      var inviter = await app.firebaseContext.authOrNull?.getUser(userId);
      var inviterName = inviter?.displayName;
      if (inviterName == null || inviterName.trim().isEmpty) {
        inviterName = inviter?.email;
      }
      await mailer.sendEmailInvite(
        FestenaoEmailInviteMail(
          invite: invite.toCvEmailInvite(),
          inviterName: inviterName,
        ),
      );
      return true;
    } catch (e) {
      // The function logs: the invite is there, the mail is not.
      // ignore: avoid_print
      print('email invite $inviteId mail error: $e');
      return false;
    }
  }

  /// Handles the get user info command: the account information (name,
  /// email) of a user, to fill an access being edited.
  ///
  /// An app admin reads any user. An admin of the entity reads only the
  /// users that have an access to it, so that an entity admin cannot look up
  /// the email of an arbitrary account. Anyone else gets `permission-denied`;
  /// an unknown user `not-found`.
  Future<FsCmsEntityGetUserInfoApiResult<T>> onGetUserInfoCommand(
    ApiRequest apiRequest,
  ) async {
    var query = apiRequest.query<FsCmsEntityGetUserInfoApiQuery<T>>()
      ..fromMap(apiRequest.data.v!);
    var callerUserId = _requireUserId(apiRequest);
    var entityId = _requireField(query.entityId);
    var userId = _requireField(query.userId);
    var access = await entityAccess
        .fsEntityUserAccessRef(entityId, userId)
        .get(firestore);
    var hasAccess = access.exists;
    var allowed = false;
    if (await _isEntityAdmin(entityId, callerUserId)) {
      allowed = hasAccess;
    }
    if (!allowed && await _isAppAdmin(callerUserId)) {
      allowed = true;
    }
    if (!allowed) {
      throw (ApiError()
            ..code.v = HttpsErrorCode.permissionDenied
            ..message.v = 'Not allowed to read this user'
            ..noRetry.v = true)
          .exception();
    }
    var user = await _requireUser(userId);
    return FsCmsEntityGetUserInfoApiResult<T>()
      ..userId.v = userId
      ..name.setValue(user.displayName)
      ..email.setValue(user.email)
      ..emailVerified.v = user.emailVerified
      ..disabled.v = user.disabled
      ..hasAccess.v = hasAccess;
  }

  /// Handles the list email invites command (entity admin or app admin):
  /// the invites sent on the entity and what happened to them.
  Future<FsCmsEntityListEmailInvitesApiResult<T>> onListEmailInvitesCommand(
    ApiRequest apiRequest,
  ) async {
    var query = apiRequest.query<FsCmsEntityListEmailInvitesApiQuery<T>>()
      ..fromMap(apiRequest.data.v!);
    var userId = _requireUserId(apiRequest);
    var entityId = _requireField(query.entityId);
    await _requireEmailInviteAdmin(entityId, userId);
    var invites = await entityAccess.listEntityEmailInvites(
      entityId,
      status: query.status.v,
    );
    return FsCmsEntityListEmailInvitesApiResult<T>()
      ..invites.v = invites.map((invite) => invite.toCvEmailInvite()).toList();
  }

  /// Handles the delete email invite command (entity admin or app admin):
  /// revokes it, whatever its status.
  Future<FsCmsEntityDeleteEmailInviteApiResult<T>> onDeleteEmailInviteCommand(
    ApiRequest apiRequest,
  ) async {
    var query = apiRequest.query<FsCmsEntityDeleteEmailInviteApiQuery<T>>()
      ..fromMap(apiRequest.data.v!);
    var userId = _requireUserId(apiRequest);
    var entityId = _requireField(query.entityId);
    var inviteId = _requireField(query.inviteId);
    await _requireEmailInviteAdmin(entityId, userId);
    await entityAccess.deleteEmailInviteEntity(
      inviteId: inviteId,
      entityId: entityId,
    );
    return FsCmsEntityDeleteEmailInviteApiResult<T>()
      ..entityId.setValue(entityId)
      ..inviteId.v = inviteId;
  }

  /// Handles the check email invites command (any signed in user, on app
  /// start and after login): the pending invites addressed to the caller's
  /// verified email. An unverified email gets an empty list, not an error,
  /// so that the UI can ask for the verification.
  Future<FsCmsEntityCheckEmailInvitesApiResult<T>> onCheckEmailInvitesCommand(
    ApiRequest apiRequest,
  ) async {
    var query = apiRequest.query<FsCmsEntityCheckEmailInvitesApiQuery<T>>()
      ..fromMap(apiRequest.data.v!);
    var userId = _requireUserId(apiRequest);
    var user = await _requireUser(userId);
    var email = tkCmsNormalizeInviteEmail(user.email);
    var result = FsCmsEntityCheckEmailInvitesApiResult<T>()
      ..email.setValue(email)
      ..emailVerified.v = user.emailVerified
      ..invites.v = <TkCmsCvEmailInvite>[];
    if (email == null || !user.emailVerified) {
      return result;
    }
    var invites = await entityAccess.listEmailInvites(
      email,
      status: tkCmsEmailInviteStatusPending,
    );
    var entityId = query.entityId.v;
    if (entityId != null) {
      invites = invites
          .where((invite) => invite.entityId.v == entityId)
          .toList();
    }
    result.invites.v = invites
        .map((invite) => invite.toCvEmailInvite())
        .toList();
    return result;
  }

  /// Handles the accept email invite command (the invitee): the invite must
  /// be pending and addressed to the caller's verified email; its access is
  /// merged into the user's.
  Future<FsCmsEntityAcceptEmailInviteApiResult<T>> onAcceptEmailInviteCommand(
    ApiRequest apiRequest,
  ) async {
    var query = apiRequest.query<FsCmsEntityAcceptEmailInviteApiQuery<T>>()
      ..fromMap(apiRequest.data.v!);
    var userId = _requireUserId(apiRequest);
    var entityId = _requireField(query.entityId);
    var inviteId = _requireField(query.inviteId);
    var email = await _requireVerifiedEmail(userId);
    await _checkEntityEmailInvite(entityId, inviteId);
    await entityAccess.acceptEmailInviteEntity(
      userId: userId,
      email: email,
      inviteId: inviteId,
    );
    return FsCmsEntityAcceptEmailInviteApiResult<T>()
      ..entityId.setValue(entityId)
      ..inviteId.v = inviteId;
  }

  /// Handles the discard email invite command (the invitee): the invite must
  /// be pending and addressed to the caller's verified email; no access is
  /// granted and it cannot be accepted any more.
  Future<FsCmsEntityDiscardEmailInviteApiResult<T>> onDiscardEmailInviteCommand(
    ApiRequest apiRequest,
  ) async {
    var query = apiRequest.query<FsCmsEntityDiscardEmailInviteApiQuery<T>>()
      ..fromMap(apiRequest.data.v!);
    var userId = _requireUserId(apiRequest);
    var entityId = _requireField(query.entityId);
    var inviteId = _requireField(query.inviteId);
    var email = await _requireVerifiedEmail(userId);
    await _checkEntityEmailInvite(entityId, inviteId);
    await entityAccess.discardEmailInviteEntity(
      email: email,
      inviteId: inviteId,
    );
    return FsCmsEntityDiscardEmailInviteApiResult<T>()
      ..entityId.setValue(entityId)
      ..inviteId.v = inviteId;
  }
}

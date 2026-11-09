import 'package:festenao_common/api/festenao_api_app_status.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// The commands always served, whatever the status: the server's own
/// (timestamp, info, the scheduled cron).
const _alwaysServedCommands = {
  commandTimestamp,
  commandInfo,
  commandInfoFb,
  commandCron,
};

/// The commands served in read only besides the `get` and `list` ones.
const _readCommands = {apiCommandEcho, apiCommandAuthMe};

/// True when [command] only reads, so that it is served in read only
/// ([FestenaoAppStatusMode.readOnly]): its last segment starts with `get` or
/// `list` (`user-plan/get`, `entity/project/get-create-limit`,
/// `custom-domain/list`), or it is one of the server's reading commands
/// (timestamp, info, echo, auth/me).
bool festenaoAppStatusIsReadCommand(String command) {
  if (_alwaysServedCommands.contains(command) ||
      _readCommands.contains(command)) {
    return true;
  }
  var last = command.substring(command.lastIndexOf('/') + 1);
  return last.startsWith('get') || last.startsWith('list');
}

/// Whether [userId] is an admin of [app].
typedef FestenaoIsAppAdmin = Future<bool> Function(String app, String userId);

/// The status of the apps a server serves ([festenaoAppStatusDocument]) and
/// of the whole Firebase project ([festenaoGlobalStatusDocument]):
/// [requireAvailable] refuses the commands the status does not allow, a
/// server calls it first in its `onCommand` (the festenao projects server
/// app does once its `appStatusHandler` is set).
///
/// The statuses are read at most once per [cacheDuration] per server
/// instance, so a change is seen by every instance within that time; the
/// admin check costs one read, only for a command the status refuses.
class FestenaoAppStatusHandler {
  /// The apps whose status it checks: a request names its app (the api
  /// service's), the first one when it names none; any other app only has
  /// the global status.
  final List<String> apps;

  /// The firestore of the apps.
  final Firestore firestore;

  /// How long a status read is kept.
  final Duration cacheDuration;

  /// The app admins (their commands always served), the app entity access
  /// rows (`access/app/entity_id/<app>`) when null.
  final FestenaoIsAppAdmin? isAppAdmin;

  /// The clock of the cache, now when null (the tests set one).
  final DateTime Function()? now;

  /// Creates the handler.
  FestenaoAppStatusHandler({
    required this.apps,
    required this.firestore,
    this.cacheDuration = const Duration(seconds: 30),
    this.isAppAdmin,
    this.now,
  }) : assert(apps.isNotEmpty) {
    initFestenaoAppStatusBuilders();
  }

  final _cache = <String, ({DateTime read, FestenaoAppStatus status})>{};

  late final _appDb = TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsApp>(
    entityCollectionInfo: tkCmsFsAppCollectionInfo,
    firestore: firestore,
    rootDocument: null,
  );

  DateTime _now() => now?.call() ?? DateTime.now();

  Future<FestenaoAppStatus> _statusOf(
    CvDocumentReference<FsFestenaoAppStatus> ref,
  ) async {
    var path = ref.path;
    var cached = _cache[path];
    var now = _now();
    if (cached != null && now.difference(cached.read) < cacheDuration) {
      return cached.status;
    }
    FestenaoAppStatus status;
    try {
      status = FestenaoAppStatus.fromFs(await ref.get(firestore));
    } catch (_) {
      // Never refuse on an unknown status, keep the last one known.
      status = cached?.status ?? FestenaoAppStatus.normal;
    }
    _cache[path] = (read: now, status: status);
    return status;
  }

  /// The app of a request, null when it is not one of [apps].
  String? _appOrNull(ApiRequest apiRequest) {
    var app = apiRequest.app.v ?? apps.first;
    return apps.contains(app) ? app : null;
  }

  /// The status [app] runs with (the stricter of the global one and its
  /// own, the global one only when [app] is null or not served), cached.
  Future<FestenaoAppStatus> statusOf(String? app) async {
    var global = await _statusOf(festenaoGlobalStatusDocument());
    if (app == null || !apps.contains(app)) {
      return global;
    }
    return global.stricter(await _statusOf(festenaoAppStatusDocument(app)));
  }

  /// Forgets the statuses read, the next command reads them again (a test,
  /// or a tool that just changed them).
  void clearCache() => _cache.clear();

  Future<bool> _isAppAdmin(String app, String userId) async {
    if (isAppAdmin case var isAppAdmin?) {
      return await isAppAdmin(app, userId);
    }
    var access = await _appDb.fsEntityUserAccessRef(app, userId).get(firestore);
    return access.exists && access.isAdmin;
  }

  /// Refuses with `unavailable` (no retry, its `details` holding the mode,
  /// see [festenaoApiErrorAppStatusMode]) a request the status does not
  /// allow: in maintenance any command, in read only the ones that change
  /// something ([festenaoAppStatusIsReadCommand]). The server's own
  /// commands (timestamp, info, cron) and the app admins' are always served.
  Future<void> requireAvailable(ApiRequest apiRequest) async {
    var command = apiRequest.command.v ?? '';
    if (_alwaysServedCommands.contains(command)) {
      return;
    }
    var app = _appOrNull(apiRequest);
    var status = await statusOf(app);
    await _require(
      apiRequest,
      status,
      app: app ?? apiRequest.app.v,
      write: !festenaoAppStatusIsReadCommand(command),
    );
  }

  /// The status of the project [projectId] of [app] (its own document,
  /// `festenaoProjectStatusDocument`), cached.
  Future<FestenaoAppStatus> projectStatusOf(String app, String projectId) =>
      _statusOf(festenaoProjectStatusDocument(app, projectId));

  /// Refuses as [requireAvailable] a request on the project [projectId] of
  /// [app] its status does not allow (the stricter of the app status and
  /// the project's): a handler acting on a project calls it (publishing a
  /// festival, say). [write] false for a command that only reads. The app
  /// admins are always served.
  Future<void> requireProjectAvailable(
    ApiRequest apiRequest, {
    required String app,
    required String projectId,
    bool write = true,
  }) async {
    var status = (await statusOf(
      app,
    )).stricter(await projectStatusOf(app, projectId));
    await _require(apiRequest, status, app: app, write: write, project: true);
  }

  Future<void> _require(
    ApiRequest apiRequest,
    FestenaoAppStatus status, {
    required String? app,
    required bool write,
    bool project = false,
  }) async {
    if (status.isNormal) {
      return;
    }
    if (status.isReadOnly && !write) {
      return;
    }
    var userId = apiRequest.userId.v;
    if (userId != null && app != null && await _isAppAdmin(app, userId)) {
      return;
    }
    var what = project ? 'This project' : 'The service';
    throw (ApiError()
          ..code.v = HttpsErrorCode.unavailable
          ..message.v =
              status.messageFor(null) ??
              (status.isReadOnly
                  ? '$what is read only for now, changes are not accepted'
                  : '$what is under maintenance')
          ..details.v = (CvMapModel()
            ..[festenaoAppStatusErrorDetailsKey] = status.mode.value)
          ..noRetry.v = true)
        .exception();
  }
}

import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:rxdart/rxdart.dart';

/// The collection of the public infos of an app (`app/<app>/public/get/info`)
/// or of the whole Firebase project (`public/get/info`): read by anyone
/// (the `public/get` rules), written by the server or a support tool.
const festenaoPublicInfoCollectionId = 'info';

/// The status document id in [festenaoPublicInfoCollectionId].
const festenaoAppStatusDocumentId = 'status';

/// The `details` key of the api error of a command refused by the status
/// (`unavailable`): the mode, see [festenaoApiErrorAppStatusMode].
const festenaoAppStatusErrorDetailsKey = 'appStatus';

/// How an app (or every app of a Firebase project) runs.
enum FestenaoAppStatusMode {
  /// Everything on.
  normal('normal'),

  /// Reading only: the apps show a banner and the server refuses the
  /// commands that change something (app admins excepted).
  readOnly('read_only'),

  /// Nothing: the apps show the maintenance screen and the server refuses
  /// every command (app admins excepted).
  maintenance('maintenance');

  /// The value stored in the status document.
  final String value;

  const FestenaoAppStatusMode(this.value);

  /// The mode of a stored [value]: [normal] when null or empty, and
  /// [maintenance] when unknown (a mode a newer tool wrote is at least as
  /// strict as maintenance for an older app).
  static FestenaoAppStatusMode parse(String? value) {
    if (value == null || value.isEmpty) {
      return normal;
    }
    for (var mode in values) {
      if (mode.value == value) {
        return mode;
      }
    }
    return maintenance;
  }

  /// The mode of a command line value (`normal`, `read_only` or
  /// `read-only`, `maintenance`), null when unknown.
  static FestenaoAppStatusMode? tryParse(String value) {
    var normalized = value.replaceAll('-', '_');
    for (var mode in values) {
      if (mode.value == normalized) {
        return mode;
      }
    }
    return null;
  }

  /// The stricter of this mode and [other].
  FestenaoAppStatusMode stricter(FestenaoAppStatusMode other) =>
      other.index > index ? other : this;
}

/// The status document of an app or of the whole Firebase project
/// ([festenaoAppStatusDocument], [festenaoGlobalStatusDocument]).
class FsFestenaoAppStatus extends CvFirestoreDocumentBase {
  /// The mode ([FestenaoAppStatusMode.value]), normal when null.
  final mode = CvField<String>('mode');

  /// The message shown to the users, in any language: the one shown when
  /// [messages] has none in theirs.
  final message = CvField<String>('message');

  /// The message by language code (`fr`, `en`).
  final messages = CvField<Map>('messages');

  /// When the maintenance should end, shown only (the mode does not end by
  /// itself).
  final until = CvField<Timestamp>('until');

  /// Who changed it last (a user id, or a tool and the user running it).
  final updatedBy = CvField<String>('updatedBy');

  /// When it was changed last.
  final updated = CvField<Timestamp>('updated');

  @override
  CvFields get fields => [mode, message, messages, until, updatedBy, updated];
}

/// `app/<app>/public/get/info/status`: the status of [app], read by anyone.
CvDocumentReference<FsFestenaoAppStatus> festenaoAppStatusDocument(
  String app,
) => fsAppRoot(app)
    .collection<CvFirestoreDocument>('public')
    .doc('get')
    .collection<FsFestenaoAppStatus>(festenaoPublicInfoCollectionId)
    .doc(festenaoAppStatusDocumentId);

/// `public/get/info/status`: the status of every app of the Firebase
/// project, read by anyone.
CvDocumentReference<FsFestenaoAppStatus> festenaoGlobalStatusDocument() =>
    CvCollectionReference<CvFirestoreDocument>('public')
        .doc('get')
        .collection<FsFestenaoAppStatus>(festenaoPublicInfoCollectionId)
        .doc(festenaoAppStatusDocumentId);

/// The collection of the project statuses of an app
/// (`app/<app>/public/get/project_status/<projectId>`).
const festenaoProjectStatusCollectionId = 'project_status';

/// `app/<app>/public/get/project_status/<projectId>`: the status of one
/// project of [app] (a festival read only, or taken down), read by anyone,
/// written by the app admins (the server, the console, a support tool):
/// the project writers cannot lift it.
CvDocumentReference<FsFestenaoAppStatus> festenaoProjectStatusDocument(
  String app,
  String projectId,
) => fsAppRoot(app)
    .collection<CvFirestoreDocument>('public')
    .doc('get')
    .collection<FsFestenaoAppStatus>(festenaoProjectStatusCollectionId)
    .doc(projectId);

/// The status an app runs with: the stricter of the status of the whole
/// Firebase project and its own ([FestenaoAppStatus.stricter]).
class FestenaoAppStatus {
  /// Normal, the status of an app without status document.
  static const normal = FestenaoAppStatus();

  /// The mode.
  final FestenaoAppStatusMode mode;

  /// The message in any language, see [messageFor].
  final String? message;

  /// The message by language code.
  final Map<String, String> messages;

  /// When it should end, shown only.
  final DateTime? until;

  /// A status.
  const FestenaoAppStatus({
    this.mode = FestenaoAppStatusMode.normal,
    this.message,
    this.messages = const {},
    this.until,
  });

  /// The status of a status document, [normal] when it does not exist.
  factory FestenaoAppStatus.fromFs(FsFestenaoAppStatus fs) {
    if (!fs.exists) {
      return normal;
    }
    return FestenaoAppStatus(
      mode: FestenaoAppStatusMode.parse(fs.mode.v),
      message: fs.message.v,
      messages: {
        for (var entry in (fs.messages.v ?? const {}).entries)
          if (entry.value is String && (entry.value as String).isNotEmpty)
            entry.key.toString(): entry.value as String,
      },
      until: fs.until.v?.toDateTime(),
    );
  }

  /// True when everything is on.
  bool get isNormal => mode == FestenaoAppStatusMode.normal;

  /// True when reading only.
  bool get isReadOnly => mode == FestenaoAppStatusMode.readOnly;

  /// True when in maintenance.
  bool get isMaintenance => mode == FestenaoAppStatusMode.maintenance;

  /// The message in [languageCode], else [message], else the first one.
  String? messageFor(String? languageCode) {
    var text = messages[languageCode] ?? message;
    if (text != null && text.isNotEmpty) {
      return text;
    }
    return messages.values.firstOrNull;
  }

  /// The stricter of this status and [other] (this one when the same mode).
  FestenaoAppStatus stricter(FestenaoAppStatus other) =>
      other.mode.index > mode.index ? other : this;

  @override
  bool operator ==(Object other) =>
      other is FestenaoAppStatus &&
      other.mode == mode &&
      other.message == message &&
      other.until == until &&
      _mapEquals(other.messages, messages);

  @override
  int get hashCode => Object.hash(mode, message, until, messages.length);

  @override
  String toString() =>
      'FestenaoAppStatus(${mode.value}${message == null ? '' : ', $message'})';
}

bool _mapEquals(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var entry in a.entries) {
    if (b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

/// The status [app] runs with, following both status documents (the
/// project's and the app's): [FestenaoAppStatus.normal] first and when a
/// document cannot be read (an app never stops on an unknown status).
Stream<FestenaoAppStatus> festenaoAppStatusOnSnapshot(
  Firestore firestore, {
  required String app,
}) {
  initFestenaoAppStatusBuilders();
  Stream<FestenaoAppStatus> statusOf(
    CvDocumentReference<FsFestenaoAppStatus> ref,
  ) => ref
      .onSnapshot(firestore)
      .map(FestenaoAppStatus.fromFs)
      .onErrorReturn(FestenaoAppStatus.normal)
      .startWith(FestenaoAppStatus.normal);
  return Rx.combineLatest2(
    statusOf(festenaoGlobalStatusDocument()),
    statusOf(festenaoAppStatusDocument(app)),
    (FestenaoAppStatus global, FestenaoAppStatus own) => global.stricter(own),
  ).distinct();
}

/// The status [app] runs with now (see [festenaoAppStatusOnSnapshot]).
Future<FestenaoAppStatus> festenaoAppStatusGet(
  Firestore firestore, {
  required String app,
}) async {
  initFestenaoAppStatusBuilders();
  Future<FestenaoAppStatus> statusOf(
    CvDocumentReference<FsFestenaoAppStatus> ref,
  ) async {
    try {
      return FestenaoAppStatus.fromFs(await ref.get(firestore));
    } catch (_) {
      return FestenaoAppStatus.normal;
    }
  }

  var statuses = await Future.wait([
    statusOf(festenaoGlobalStatusDocument()),
    statusOf(festenaoAppStatusDocument(app)),
  ]);
  return statuses[0].stricter(statuses[1]);
}

/// The own status of the project [projectId] of [app] (its document only:
/// the app gate already shows the app and project-wide ones), following
/// it: [FestenaoAppStatus.normal] first and when it cannot be read.
Stream<FestenaoAppStatus> festenaoProjectStatusOnSnapshot(
  Firestore firestore, {
  required String app,
  required String projectId,
}) {
  initFestenaoAppStatusBuilders();
  return festenaoProjectStatusDocument(app, projectId)
      .onSnapshot(firestore)
      .map(FestenaoAppStatus.fromFs)
      .onErrorReturn(FestenaoAppStatus.normal)
      .startWith(FestenaoAppStatus.normal)
      .distinct();
}

/// The status the project [projectId] of [app] runs with now: the stricter
/// of the project-wide, the app and the project statuses.
Future<FestenaoAppStatus> festenaoProjectStatusGet(
  Firestore firestore, {
  required String app,
  required String projectId,
}) async {
  var appStatus = await festenaoAppStatusGet(firestore, app: app);
  try {
    return appStatus.stricter(
      FestenaoAppStatus.fromFs(
        await festenaoProjectStatusDocument(app, projectId).get(firestore),
      ),
    );
  } catch (_) {
    return appStatus;
  }
}

/// The mode of an api error of a command the status refused, null for any
/// other error.
FestenaoAppStatusMode? festenaoApiErrorAppStatusMode(ApiError? error) {
  // The functions https error code unavailable.
  if (error?.code.v != 'unavailable') {
    return null;
  }
  var value = error?.details.v?[festenaoAppStatusErrorDetailsKey];
  return value is String ? FestenaoAppStatusMode.parse(value) : null;
}

var _buildersInitialized = false;

/// Registers the status model (idempotent).
void initFestenaoAppStatusBuilders() {
  if (_buildersInitialized) {
    return;
  }
  _buildersInitialized = true;
  cvAddConstructors([FsFestenaoAppStatus.new]);
}

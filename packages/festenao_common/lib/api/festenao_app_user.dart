/// The users of an app: the seen ping of the clients, the admin console
/// (list, purge) and the merge of an anonymous user, see
/// `doc/anonymous_user_strategy.md` (festenaoprv).
library;

export 'package:tekartik_prefs/kv_store.dart' show KvStore, KvStoreExt;
export 'package:tkcms_common/tkcms_app_user.dart';
